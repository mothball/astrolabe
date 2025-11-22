from math import sin, cos, sqrt, atan2
from algorithm import parallelize, vectorize
from memory import UnsafePointer, bitcast
from sys.intrinsics import prefetch, PrefetchOptions
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

# SIMD WIDTH - FP32 gives 2x SIMD width on same hardware
alias SIMD_WIDTH = 8  # Same as FP64, but using FP32
alias Vec = SIMD[DType.float32, SIMD_WIDTH]
alias BoolVec = SIMD[DType.bool, SIMD_WIDTH]

@always_inline
fn select_simd(cond: BoolVec, t: Vec, f: Vec) -> Vec:
    # Manual select using bitwise operations
    var mask = cond.cast[DType.int32]()
    mask = -mask
    var mask_u32 = mask.cast[DType.uint32]()
    var t_u32 = bitcast[DType.uint32, SIMD_WIDTH](t)
    var f_u32 = bitcast[DType.uint32, SIMD_WIDTH](f)
    var res_u32 = (t_u32 & mask_u32) | (f_u32 & ~mask_u32)
    return bitcast[DType.float32, SIMD_WIDTH](res_u32)

struct SGP4Constants(Copyable, Movable, ImplicitlyCopyable):
    var n0dp: Vec
    var a0dp: Vec
    var ecco: Vec
    var inclo: Vec
    var nodeo: Vec
    var argpo: Vec
    var mo: Vec
    var omgdot: Vec
    var xnodot: Vec
    var xmdot: Vec
    var c1: Vec
    var sinio: Vec
    var cosio: Vec

    fn __init__(
        out self, n0dp: Vec, a0dp: Vec, ecco: Vec, inclo: Vec,
        nodeo: Vec, argpo: Vec, mo: Vec, omgdot: Vec, xnodot: Vec,
        xmdot: Vec, c1: Vec, sinio: Vec, cosio: Vec
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
fn sgp4_init_adaptive(
    no_kozai: Vec, ecco: Vec, inclo: Vec, nodeo: Vec,
    argpo: Vec, mo: Vec, bstar: Vec
) -> SGP4Constants:
    # Cast constants to FP32
    alias KE_32 = Float32(KE)
    alias TOTHRD_32 = Float32(TOTHRD)
    alias CK2_32 = Float32(CK2)
    alias KMPER_32 = Float32(KMPER)
    
    var a1 = (KE_32 / no_kozai) ** TOTHRD_32
    var cosi0 = cos(inclo)
    var theta2 = cosi0 * cosi0
    var x3thm1 = 3.0 * theta2 - 1.0
    var beta02 = 1.0 - ecco * ecco
    var beta0 = sqrt(beta02)
    var dela2 = 1.5 * CK2_32 * x3thm1 / (beta0 * beta02)
    var del1 = dela2 / (a1 * a1)
    var a0 = a1 * (1.0 - del1 * (1.0 / 3.0 + del1 * (1.0 + 134.0 / 81.0 * del1)))
    var del0 = dela2 / (a0 * a0)
    var n0dp = no_kozai / (1.0 + del0)
    var a0dp = (KE_32 / n0dp) ** TOTHRD_32
    
    var perige = a0dp * (1.0 - ecco) - 1.0
    var s = Vec(20.0 / KMPER_32)
    var s1_val = 78.0 / KMPER_32
    var s_cond = perige - s1_val
    
    s = select_simd(s_cond.lt(0.0), s_cond, s)
    s = select_simd(s.lt(s1_val), Vec(s1_val), s)
    
    var s4 = 1.0 + s
    var pinvsq = 1.0 / ((a0dp * beta02) ** 2.0)
    var xi = 1.0 / (a0dp - s4)
    var eta = a0dp * xi * ecco
    var etasq = eta * eta
    var eeta = ecco * eta
    var psisq = abs(1.0 - etasq)
    
    var q0 = 120.0 / KMPER_32
    var coef = ((q0 - s) * xi) ** 4.0
    var coef1 = coef / (sqrt(psisq) * psisq * psisq * psisq)
    
    var c1 = bstar * coef1 * n0dp * (
        a0dp * (1.0 + 1.5 * etasq + eeta * (4.0 + etasq))
        + 0.75 * CK2_32 * xi / psisq * x3thm1 * (8.0 + 3.0 * etasq * (8.0 + etasq))
    )
    
    var sini0 = sin(inclo)
    var omgdot = -1.5 * CK2_32 * x3thm1 * pinvsq * n0dp
    var xnodot = -1.5 * CK2_32 * cosi0 * pinvsq * n0dp
    var xmdot = 1.5 * CK2_32 * x3thm1 * pinvsq * (1.0 + 3.0 * theta2) * n0dp
    
    return SGP4Constants(
        n0dp, a0dp, ecco, inclo, nodeo, argpo, mo,
        omgdot, xnodot, xmdot, c1, sini0, cosi0
    )

@always_inline
fn sin_cos_fp32(x: Vec) -> Tuple[Vec, Vec]:
    """Use standard sin/cos for FP32"""
    return (sin(x), cos(x))

@always_inline
fn sgp4_propagate_adaptive(c: SGP4Constants, tsince: Float64) -> Tuple[Vec, Vec, Vec, Vec, Vec, Vec]:
    alias KMPER_32 = Float32(KMPER)
    var t = Float32(tsince)
    
    var omega = c.argpo + c.omgdot * t
    var xnode = c.nodeo + c.xnodot * t
    var xmp = c.mo + c.xmdot * t
    
    var tsq = t * t
    var xnode_drag = xnode + c.xnodot * c.c1 * tsq
    var xmp_drag = xmp + c.n0dp * ((1.5 * c.c1 * tsq) + (c.c1 * c.c1 * tsq * t))
    var omega_drag = omega - (c.c1 * c.c1 * tsq * tsq * 0.5)
    
    # Kepler solver
    var e = xmp_drag
    for _ in range(3):
        var sc = sin_cos_fp32(e)
        var sine = sc[0]
        var cose = sc[1]
        e = e - (e - c.ecco * sine - xmp_drag) / (1.0 - c.ecco * cose)
    
    var scE = sin_cos_fp32(e)
    var sinE = scE[0]
    var cosE = scE[1]
    var el2 = c.ecco * c.ecco
    var r = c.a0dp * (1.0 - c.ecco * cosE)
    
    var scOMG = sin_cos_fp32(omega_drag)
    var sinOMG = scOMG[0]
    var cosOMG = scOMG[1]
    var scNODE = sin_cos_fp32(xnode_drag)
    var sinNODE = scNODE[0]
    var cosNODE = scNODE[1]
    
    var u = c.a0dp * (cosE - c.ecco)
    var v = c.a0dp * sqrt(1.0 - el2) * sinE
    
    var x = u * (cosNODE * cosOMG - sinNODE * sinOMG * c.cosio) - v * (cosNODE * sinOMG + sinNODE * cosOMG * c.cosio)
    var y = u * (sinNODE * cosOMG + cosNODE * sinOMG * c.cosio) + v * (sinNODE * sinOMG - cosNODE * cosOMG * c.cosio)
    var z = u * sinOMG * c.sinio + v * cosOMG * c.sinio
    
    var udot = -sqrt(c.a0dp) * sinE / r
    var vdot = sqrt(c.a0dp * (1.0 - el2)) * cosE / r
    
    var vx = udot * (cosNODE * cosOMG - sinNODE * sinOMG * c.cosio) - vdot * (cosNODE * sinOMG + sinNODE * cosOMG * c.cosio)
    var vy = udot * (sinNODE * cosOMG + cosNODE * sinOMG * c.cosio) + vdot * (sinNODE * sinOMG - cosNODE * cosOMG * c.cosio)
    var vz = udot * sinOMG * c.sinio + vdot * cosOMG * c.sinio
    
    x = x * KMPER_32
    y = y * KMPER_32
    z = z * KMPER_32
    vx = vx * KMPER_32 / 60.0
    vy = vy * KMPER_32 / 60.0
    vz = vz * KMPER_32 / 60.0
    
    return (x, y, z, vx, vy, vz)

fn propagate_batch_adaptive(
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
    @parameter
    fn worker(i: Int):
        var start = i * 4096
        var end = min(start + 4096, num_satellites)
        var mutable_results = results.unsafe_mut_cast[True]()
        
        for j in range(start, end, SIMD_WIDTH):
            if j + SIMD_WIDTH <= end:
                if j + SIMD_WIDTH * 2 <= end:
                    prefetch[PrefetchOptions().for_read().high_locality()](no_kozai + j + SIMD_WIDTH)
                    prefetch[PrefetchOptions().for_read().high_locality()](ecco + j + SIMD_WIDTH)
                
                # Load as FP64 and cast to FP32
                var constants = sgp4_init_adaptive(
                    no_kozai.load[width=SIMD_WIDTH](j).cast[DType.float32](),
                    ecco.load[width=SIMD_WIDTH](j).cast[DType.float32](),
                    inclo.load[width=SIMD_WIDTH](j).cast[DType.float32](),
                    nodeo.load[width=SIMD_WIDTH](j).cast[DType.float32](),
                    argpo.load[width=SIMD_WIDTH](j).cast[DType.float32](),
                    mo.load[width=SIMD_WIDTH](j).cast[DType.float32](),
                    bstar.load[width=SIMD_WIDTH](j).cast[DType.float32]()
                )
                
                for t_idx in range(num_times):
                    var result = sgp4_propagate_adaptive(constants, times[t_idx])
                    var base_idx = t_idx * num_satellites * 6 + j
                    
                    # Cast FP32 results back to FP64 for storage
                    mutable_results.store(base_idx + 0 * num_satellites, result[0].cast[DType.float64]())
                    mutable_results.store(base_idx + 1 * num_satellites, result[1].cast[DType.float64]())
                    mutable_results.store(base_idx + 2 * num_satellites, result[2].cast[DType.float64]())
                    mutable_results.store(base_idx + 3 * num_satellites, result[3].cast[DType.float64]())
                    mutable_results.store(base_idx + 4 * num_satellites, result[4].cast[DType.float64]())
                    mutable_results.store(base_idx + 5 * num_satellites, result[5].cast[DType.float64]())
            else:
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
