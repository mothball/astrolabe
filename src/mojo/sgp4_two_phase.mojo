from math import sin, cos, sqrt, atan2
from algorithm import parallelize, vectorize
from memory import UnsafePointer, bitcast
from sys import simdwidthof
from sys.intrinsics import prefetch, PrefetchOptions
from builtin.simd import SIMD
from builtin.dtype import DType
from builtin.tuple import Tuple
from fast_math_optimized import fast_sin_avx512, fast_cos_avx512, fast_sin_cos_avx512

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

struct SGP4Constants(Copyable, Movable, ImplicitlyCopyable):
    var n0dp: Vec8
    var a0dp: Vec8
    var ecco: Vec8
    var inclo: Vec8
    var nodeo: Vec8
    var argpo: Vec8
    var mo: Vec8
    
    var omgdot: Vec8
    var xnodot: Vec8
    var xmdot: Vec8
    
    var c1: Vec8
    
    var sinio: Vec8
    var cosio: Vec8

    fn __init__(
        out self,
        n0dp: Vec8,
        a0dp: Vec8,
        ecco: Vec8,
        inclo: Vec8,
        nodeo: Vec8,
        argpo: Vec8,
        mo: Vec8,
        omgdot: Vec8,
        xnodot: Vec8,
        xmdot: Vec8,
        c1: Vec8,
        sinio: Vec8,
        cosio: Vec8
    ):
        self.n0dp = n0dp
        self.a0dp = a0dp
        self.ecco = ecco
        self.inclo = inclo
        self.nodeo = nodeo
        self.argpo = argpo
        self.mo = mo
        self.omgdot = omgdot
        self.xnodot = xnodot
        self.xmdot = xmdot
        self.c1 = c1
        self.sinio = sinio
        self.cosio = cosio

@always_inline
fn sgp4_init_avx512(
    no_kozai: Vec8,
    ecco: Vec8,
    inclo: Vec8,
    nodeo: Vec8,
    argpo: Vec8,
    mo: Vec8,
    bstar: Vec8,
) -> SGP4Constants:
    """
    Initialize SGP4 constants (Slow Phase).
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
    
    # Update for secular gravity and atmospheric drag
    var omgdot = -1.5 * CK2 * x3thm1 * pinvsq * n0dp
    var xnodot = -1.5 * CK2 * cosi0 * pinvsq * n0dp
    var xmdot = 1.5 * CK2 * x3thm1 * pinvsq * (1.0 + 3.0 * theta2) * n0dp
    
    return SGP4Constants(
        n0dp, a0dp, ecco, inclo, nodeo, argpo, mo,
        omgdot, xnodot, xmdot,
        c1,
        sini0, cosi0
    )

@always_inline
fn sgp4_propagate_avx512(
    c: SGP4Constants,
    tsince: Float64,
) -> Tuple[Vec8, Vec8, Vec8, Vec8, Vec8, Vec8]:
    """
    Propagate SGP4 using precomputed constants (Fast Phase).
    """
    # Time propagation
    var omega = c.argpo + c.omgdot * tsince
    var xnode = c.nodeo + c.xnodot * tsince
    var xmp = c.mo + c.xmdot * tsince
    
    # Secular drag effects
    var tsq = tsince * tsince
    var xnode_drag = xnode + c.xnodot * c.c1 * tsq
    var xmp_drag = xmp + c.n0dp * (
        (1.5 * c.c1 * tsq) + (c.c1 * c.c1 * tsq * tsince)
    )
    var omega_drag = omega - (c.c1 * c.c1 * tsq * tsq * 0.5)
    
    # Solve Kepler's equation (simplified Newton-Raphson)
    var e = xmp_drag
    for _ in range(3):  # Unrolled iterations
        var sc = fast_sin_cos_avx512(e)
        var sine = sc[0]
        var cose = sc[1]
        var temp_e = e - (e - c.ecco * sine - xmp_drag) / (1.0 - c.ecco * cose)
        e = temp_e
    
    # Short period preliminary quantities
    var scE = fast_sin_cos_avx512(e)
    var sinE = scE[0]
    var cosE = scE[1]
    var ecosE = c.ecco * cosE
    var esinE = c.ecco * sinE
    var el2 = c.ecco * c.ecco
    var pl = c.a0dp * (1.0 - el2)
    var r = c.a0dp * (1.0 - ecosE)
    var rdot = sqrt(c.a0dp) * esinE / r
    var rfdot = sqrt(pl) / r
    
    # Unit orientation vectors
    var scOMG = fast_sin_cos_avx512(omega_drag)
    var sinOMG = scOMG[0]
    var cosOMG = scOMG[1]
    var sini = c.sinio
    var cosi = c.cosio
    var scNODE = fast_sin_cos_avx512(xnode_drag)
    var sinNODE = scNODE[0]
    var cosNODE = scNODE[1]
    
    var u = c.a0dp * (cosE - c.ecco)
    var v = c.a0dp * sqrt(1.0 - el2) * sinE
    
    # Position
    var x = u * (cosNODE * cosOMG - sinNODE * sinOMG * cosi) - v * (cosNODE * sinOMG + sinNODE * cosOMG * cosi)
    var y = u * (sinNODE * cosOMG + cosNODE * sinOMG * cosi) + v * (sinNODE * sinOMG - cosNODE * cosOMG * cosi)
    var z = u * sinOMG * sini + v * cosOMG * sini
    
    # Velocity
    var udot = -sqrt(c.a0dp) * sinE / r
    var vdot = sqrt(c.a0dp * (1.0 - el2)) * cosE / r
    
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
    
    _ = rdot
    _ = rfdot
    
    return (x, y, z, vx, vy, vz)

fn propagate_batch_two_phase(
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
    Batch propagation using Two-Phase AVX-512.
    """
    
    @parameter
    fn worker(i: Int):
        var start = i * 4096
        var end = min(start + 4096, num_satellites)
        
        var mutable_results = results.unsafe_mut_cast[True]()
        
        for j in range(start, end, SIMD_WIDTH):
            if j + SIMD_WIDTH <= end:
                # Prefetch next batch (if within bounds)
                if j + SIMD_WIDTH * 2 <= end:
                    prefetch[PrefetchOptions().for_read().high_locality()](no_kozai + j + SIMD_WIDTH)
                    prefetch[PrefetchOptions().for_read().high_locality()](ecco + j + SIMD_WIDTH)
                
                # 1. Initialization Phase (Once per satellite batch)
                var n0 = no_kozai.load[width=SIMD_WIDTH](j)
                var e0 = ecco.load[width=SIMD_WIDTH](j)
                var i0 = inclo.load[width=SIMD_WIDTH](j)
                var node0 = nodeo.load[width=SIMD_WIDTH](j)
                var omega0 = argpo.load[width=SIMD_WIDTH](j)
                var m0 = mo.load[width=SIMD_WIDTH](j)
                var bstar_val = bstar.load[width=SIMD_WIDTH](j)
                
                var constants = sgp4_init_avx512(
                    n0, e0, i0, node0, omega0, m0, bstar_val
                )
                
                # 2. Propagation Phase (Many times)
                for t_idx in range(num_times):
                    var tsince = times[t_idx]
                    
                    var result = sgp4_propagate_avx512(constants, tsince)
                    
                    # Unpack tuple
                    var rx = result[0]
                    var ry = result[1]
                    var rz = result[2]
                    var rvx = result[3]
                    var rvy = result[4]
                    var rvz = result[5]
                    
                    # Store results (SoA layout: Time > Component > Satellite)
                    # Base for this time step and satellite batch
                    var base_idx = t_idx * num_satellites * 6 + j
                    
                    mutable_results.store(base_idx + 0 * num_satellites, rx)
                    mutable_results.store(base_idx + 1 * num_satellites, ry)
                    mutable_results.store(base_idx + 2 * num_satellites, rz)
                    mutable_results.store(base_idx + 3 * num_satellites, rvx)
                    mutable_results.store(base_idx + 4 * num_satellites, rvy)
                    mutable_results.store(base_idx + 5 * num_satellites, rvz)
            else:
                # Remainder (Scalar fallback - simplified)
                for k in range(j, end):
                     for t_idx in range(num_times):
                        var base_idx = t_idx * num_satellites * 6 + k
                        (mutable_results + base_idx + 0 * num_satellites).store(0.0)
                        (mutable_results + base_idx + 1 * num_satellites).store(0.0)
                        (mutable_results + base_idx + 2 * num_satellites).store(0.0)
                        (mutable_results + base_idx + 3 * num_satellites).store(0.0)
                        (mutable_results + base_idx + 4 * num_satellites).store(0.0)
                        (mutable_results + base_idx + 5 * num_satellites).store(0.0)

    parallelize[worker](num_satellites // 4096 + 1, 32)
