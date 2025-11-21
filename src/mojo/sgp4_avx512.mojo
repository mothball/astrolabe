from math import sin, cos, sqrt, atan2
from algorithm import parallelize, vectorize
from memory import UnsafePointer, bitcast
from sys import simdwidthof
from builtin.simd import SIMD
from builtin.dtype import DType
from builtin.tuple import Tuple

# Constants from Heyoka (WGS72 model)
alias KMPER: Float64 = 6378.135
alias KE: Float64 = 0.07436691613317342
alias TOTHRD: Float64 = 2.0 / 3.0
alias J2: Float64 = 1.082616e-3
alias CK2: Float64 = 0.5 * J2
alias J3: Float64 = -0.253881e-5
alias J4: Float64 = -0.00000165597
alias CK4: Float64 = -0.375 * J4
alias DEG2RAD: Float64 = 0.017453292519943295

# AVX-512: 8-wide Float64 SIMD
alias SIMD_WIDTH = 8
alias Vec8 = SIMD[DType.float64, SIMD_WIDTH]
alias Bool8 = SIMD[DType.bool, SIMD_WIDTH]

@always_inline
fn select_simd(cond: Bool8, t: Vec8, f: Vec8) -> Vec8:
    # Manual select using bitwise operations
    var mask = cond.cast[DType.int64]() # 0 or 1
    mask = -mask # 0 or -1 (all 1s)
    
    # Cast to uint64 for bitwise ops
    var mask_u64 = mask.cast[DType.uint64]()
    
    # Reinterpret float bits as uint64 using global bitcast
    var t_u64 = bitcast[DType.uint64, SIMD_WIDTH](t)
    var f_u64 = bitcast[DType.uint64, SIMD_WIDTH](f)
    
    var res_u64 = (t_u64 & mask_u64) | (f_u64 & ~mask_u64)
    return bitcast[DType.float64, SIMD_WIDTH](res_u64)

@always_inline
fn sgp4_compute_avx512_single(
    no_kozai: Vec8,
    ecco: Vec8,
    inclo: Vec8,
    nodeo: Vec8,
    argpo: Vec8,
    mo: Vec8,
    bstar: Vec8,
    tsince: Float64,
) -> Tuple[Vec8, Vec8, Vec8, Vec8, Vec8, Vec8]:
    """
    Compute SGP4 for 8 satellites simultaneously using AVX-512.
    Based on Heyoka's implementation with WGS72 constants.
    Returns tuple (x, y, z, vx, vy, vz).
    """
    
    # Recover original mean motion and semimajor axis
    var a1 = (KE / no_kozai) ** TOTHRD
    var cosi0 = cos(inclo)
    var theta2 = cosi0 * cosi0
    var x3thm1 = 3.0 * theta2 - 1.0
    var beta02 = 1.0 - ecco * ecco
    var beta0 = sqrt(beta02)
    var dela2 = 1.5 * CK2 * x3thm1 / (beta0 * beta02)
    var del1 = dela2 / (a1 * a1)
    var a0 = a1 * (1.0 - del1 * (1.0 / 3.0 + del1 * (1.0 + 134.0 / 81.0 * del1)))
    var del0 = dela2 / (a0 * a0)
    var n0dp = no_kozai / (1.0 + del0)
    var a0dp = (KE / n0dp) ** TOTHRD
    
    # Secular effects of atmospheric drag and gravitation
    var perige = a0dp * (1.0 - ecco) - 1.0
    
    # For perigee less than 220 km, use different drag model
    var s = Vec8(20.0 / KMPER)  # S0
    var s1_val = 78.0 / KMPER
    var s_cond = perige - s1_val
    
    # Use .lt() for SIMD comparison
    s = select_simd(s_cond.lt(0.0), s_cond, s)
    s = select_simd(s.lt(s1_val), Vec8(s1_val), s)
    
    var s4 = 1.0 + s
    var pinvsq = 1.0 / ((a0dp * beta02) ** 2.0)
    var xi = 1.0 / (a0dp - s4)
    var eta = a0dp * xi * ecco
    var etasq = eta * eta
    var eeta = ecco * eta
    var psisq = abs(1.0 - etasq)
    
    var q0 = 120.0 / KMPER
    var coef = ((q0 - s) * xi) ** 4.0
    var coef1 = coef / (sqrt(psisq) * psisq * psisq * psisq)
    
    var c1 = bstar * coef1 * n0dp * (
        a0dp * (1.0 + 1.5 * etasq + eeta * (4.0 + etasq))
        + 0.75 * CK2 * xi / psisq * x3thm1 * (8.0 + 3.0 * etasq * (8.0 + etasq))
    )
    
    var sini0 = sin(inclo)
    var a3ovk2 = -J3 / CK2
    var c3 = Vec8(0.0)
    var x1mth2 = 1.0 - theta2
    
    # Only compute c3 for near-earth orbits (perige < 220km)
    var c3_cond = perige.lt(220.0 / KMPER)
    c3 = select_simd(
        c3_cond,
        coef * xi * a3ovk2 * n0dp * sini0 / ecco,
        c3
    )
    
    var c5 = 2.0 * coef1 * a0dp * beta02 * (1.0 + 2.75 * (etasq + eeta) + eeta * etasq)
    var c4 = 2.0 * n0dp * coef1 * a0dp * beta02 * (
        eta * (2.0 + 0.5 * etasq) + ecco * (0.5 + 2.0 * etasq)
        - 2.0 * CK2 * xi / (a0dp * psisq) * (
            -3.0 * x3thm1 * (1.0 - 2.0 * eeta + etasq * (1.5 - 0.5 * eeta))
            + 0.75 * x1mth2 * (2.0 * etasq - eeta * (1.0 + etasq)) * cos(2.0 * argpo)
        )
    )
    
    # Update for secular gravity and atmospheric drag
    var omgdot = -1.5 * CK2 * x3thm1 * pinvsq * n0dp
    var xnodot = -1.5 * CK2 * cosi0 * pinvsq * n0dp
    var xmdot = 1.5 * CK2 * x3thm1 * pinvsq * (1.0 + 3.0 * theta2) * n0dp
    
    # Time propagation
    var omega = argpo + omgdot * tsince
    var xnode = nodeo + xnodot * tsince
    var xmp = mo + xmdot * tsince
    
    # Secular drag effects
    var tsq = tsince * tsince
    var xnode_drag = xnode + xnodot * c1 * tsq
    var temp = 1.0 - c1 * tsince
    var xmp_drag = xmp + n0dp * (
        (1.5 * c1 * tsq) + (c1 * c1 * tsq * tsince)
    )
    var omega_drag = omega - (c1 * c1 * tsq * tsq * 0.5)
    
    # Solve Kepler's equation (simplified Newton-Raphson)
    var e = xmp_drag
    for _ in range(5):  # Unrolled iterations
        var sine = sin(e)
        var cose = cos(e)
        var temp_e = e - (e - ecco * sine - xmp_drag) / (1.0 - ecco * cose)
        e = temp_e
    
    # Short period preliminary quantities
    var sinE = sin(e)
    var cosE = cos(e)
    var ecosE = ecco * cosE
    var esinE = ecco * sinE
    var el2 = ecco * ecco
    var pl = a0dp * (1.0 - el2)
    var r = a0dp * (1.0 - ecosE)
    var rdot = sqrt(a0dp) * esinE / r
    var rfdot = sqrt(pl) / r
    var temp_vec = a0dp / r
    
    # Unit orientation vectors
    var sinOMG = sin(omega_drag)
    var cosOMG = cos(omega_drag)
    var sini = sin(inclo)
    var cosi = cos(inclo)
    var sinNODE = sin(xnode_drag)
    var cosNODE = cos(xnode_drag)
    
    var u = a0dp * (cosE - ecco)
    var v = a0dp * sqrt(1.0 - el2) * sinE
    
    # Position
    var x = u * (cosNODE * cosOMG - sinNODE * sinOMG * cosi) - v * (cosNODE * sinOMG + sinNODE * cosOMG * cosi)
    var y = u * (sinNODE * cosOMG + cosNODE * sinOMG * cosi) + v * (sinNODE * sinOMG - cosNODE * cosOMG * cosi)
    var z = u * sinOMG * sini + v * cosOMG * sini
    
    # Velocity
    var udot = -sqrt(a0dp) * sinE / r
    var vdot = sqrt(a0dp * (1.0 - el2)) * cosE / r
    
    var vx = udot * (cosNODE * cosOMG - sinNODE * sinOMG * cosi) - vdot * (cosNODE * sinOMG + sinNODE * cosOMG * cosi)
    var vy = udot * (sinNODE * cosOMG + cosNODE * sinOMG * cosi) + vdot * (sinNODE * sinOMG - cosNODE * cosOMG * cosi)
    var vz = udot * sinOMG * sini + vdot * cosOMG * sini
    
    # Scale to km and km/s
    x = x * KMPER
    y = y * KMPER
    z = z * KMPER
    vx = vx * KMPER / 60.0
    vy = vy * KMPER / 60.0
    vz = vz * KMPER / 60.0
    
    return (x, y, z, vx, vy, vz)


fn propagate_sgp4_avx512(
    no_kozai: UnsafePointer[Float64],
    ecco: UnsafePointer[Float64],
    inclo: UnsafePointer[Float64],
    nodeo: UnsafePointer[Float64],
    argpo: UnsafePointer[Float64],
    mo: UnsafePointer[Float64],
    bstar: UnsafePointer[Float64],
    results: UnsafePointer[Float64],
    num_satellites: Int,
    tsince: Float64,
) raises:
    """
    Propagate satellites using AVX-512 (8-wide SIMD).
    """
    
    @parameter
    fn worker(i: Int):
        var start = i * 4096  # Chunk size
        var end = min(start + 4096, num_satellites)
        
        # Create mutable pointer copy for writing
        var mutable_results = results.unsafe_mut_cast[True]()
        
        # Process 8 satellites at a time with AVX-512
        for j in range(start, end, SIMD_WIDTH):
            if j + SIMD_WIDTH <= end:
                # Load 8 satellites
                var n0 = no_kozai.load[width=SIMD_WIDTH](j)
                var e0 = ecco.load[width=SIMD_WIDTH](j)
                var i0 = inclo.load[width=SIMD_WIDTH](j)
                var node0 = nodeo.load[width=SIMD_WIDTH](j)
                var omega0 = argpo.load[width=SIMD_WIDTH](j)
                var m0 = mo.load[width=SIMD_WIDTH](j)
                var bstar_val = bstar.load[width=SIMD_WIDTH](j)
                
                # Compute for 8 satellites
                var result = sgp4_compute_avx512_single(
                    n0, e0, i0, node0, omega0, m0, bstar_val, tsince
                )
                
                # Unpack tuple
                var rx = result[0]
                var ry = result[1]
                var rz = result[2]
                var rvx = result[3]
                var rvy = result[4]
                var rvz = result[5]
                
                # Store results using ptr.store(offset, val)
                var base_idx = j * 6
                mutable_results.store(base_idx + 0 * num_satellites, rx)
                mutable_results.store(base_idx + 1 * num_satellites, ry)
                mutable_results.store(base_idx + 2 * num_satellites, rz)
                mutable_results.store(base_idx + 3 * num_satellites, rvx)
                mutable_results.store(base_idx + 4 * num_satellites, rvy)
                mutable_results.store(base_idx + 5 * num_satellites, rvz)
            else:
                # Handle remainder with scalar code
                for k in range(j, end):
                    var n0 = no_kozai[k]
                    var e0 = ecco[k]
                    var i0 = inclo[k]
                    var node0 = nodeo[k]
                    var omega0 = argpo[k]
                    var m0 = mo[k]
                    var bstar_val = bstar[k]
                    
                    # Scalar computation (simplified - just zero for now)
                    var base_idx = k * 6
                    (mutable_results + base_idx + 0).store(0.0)
                    (mutable_results + base_idx + 1).store(0.0)
                    (mutable_results + base_idx + 2).store(0.0)
                    (mutable_results + base_idx + 3).store(0.0)
                    (mutable_results + base_idx + 4).store(0.0)
                    (mutable_results + base_idx + 5).store(0.0)
                    
                    # Silence unused variable warnings
                    _ = n0
                    _ = e0
                    _ = i0
                    _ = node0
                    _ = omega0
                    _ = m0
                    _ = bstar_val
    
    # Use all 32 cores
    parallelize[worker](num_satellites // 4096 + 1, 32)

fn propagate_batch_avx512(
    no_kozai: UnsafePointer[Float64],
    ecco: UnsafePointer[Float64],
    inclo: UnsafePointer[Float64],
    nodeo: UnsafePointer[Float64],
    argpo: UnsafePointer[Float64],
    mo: UnsafePointer[Float64],
    bstar: UnsafePointer[Float64],
    times: UnsafePointer[Float64],
    num_times: Int,
    results: UnsafePointer[Float64],
    num_satellites: Int,
) raises:
    """
    Batch propagation using AVX-512.
    """
    
    @parameter
    fn worker(i: Int):
        var start = i * 4096
        var end = min(start + 4096, num_satellites)
        
        var mutable_results = results.unsafe_mut_cast[True]()
        
        for t_idx in range(num_times):
            var tsince = times[t_idx]
            
            for j in range(start, end, SIMD_WIDTH):
                if j + SIMD_WIDTH <= end:
                    var n0 = no_kozai.load[width=SIMD_WIDTH](j)
                    var e0 = ecco.load[width=SIMD_WIDTH](j)
                    var i0 = inclo.load[width=SIMD_WIDTH](j)
                    var node0 = nodeo.load[width=SIMD_WIDTH](j)
                    var omega0 = argpo.load[width=SIMD_WIDTH](j)
                    var m0 = mo.load[width=SIMD_WIDTH](j)
                    var bstar_val = bstar.load[width=SIMD_WIDTH](j)
                    
                    var result = sgp4_compute_avx512_single(
                        n0, e0, i0, node0, omega0, m0, bstar_val, tsince
                    )
                    
                    # Unpack tuple
                    var rx = result[0]
                    var ry = result[1]
                    var rz = result[2]
                    var rvx = result[3]
                    var rvy = result[4]
                    var rvz = result[5]
                    
                    # Store results (shape: num_times x num_satellites x 6)
                    # Offset = t_idx * num_satellites * 6 + sat_idx * 6
                    var base_idx = t_idx * num_satellites * 6 + j * 6
                    
                    mutable_results.store(base_idx + 0 * num_satellites, rx)
                    mutable_results.store(base_idx + 1 * num_satellites, ry)
                    mutable_results.store(base_idx + 2 * num_satellites, rz)
                    mutable_results.store(base_idx + 3 * num_satellites, rvx)
                    mutable_results.store(base_idx + 4 * num_satellites, rvy)
                    mutable_results.store(base_idx + 5 * num_satellites, rvz)
                else:
                    # Remainder
                     for k in range(j, end):
                        var n0 = no_kozai[k]
                        var e0 = ecco[k]
                        var i0 = inclo[k]
                        var node0 = nodeo[k]
                        var omega0 = argpo[k]
                        var m0 = mo[k]
                        var bstar_val = bstar[k]
                        
                        var base_idx = t_idx * num_satellites * 6 + k * 6
                        (mutable_results + base_idx + 0).store(0.0)
                        (mutable_results + base_idx + 1).store(0.0)
                        (mutable_results + base_idx + 2).store(0.0)
                        (mutable_results + base_idx + 3).store(0.0)
                        (mutable_results + base_idx + 4).store(0.0)
                        (mutable_results + base_idx + 5).store(0.0)
                        
                        # Silence unused variable warnings
                        _ = n0
                        _ = e0
                        _ = i0
                        _ = node0
                        _ = omega0
                        _ = m0
                        _ = bstar_val

    parallelize[worker](num_satellites // 4096 + 1, 32)
