from math import sin, cos, sqrt, atan2
from algorithm import parallelize, vectorize
from memory import UnsafePointer, bitcast
from sys.intrinsics import prefetch, PrefetchOptions
from builtin.simd import SIMD
from builtin.dtype import DType
from builtin.tuple import Tuple
from fast_math_optimized import fast_sin_cos

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

# SIMD WIDTH - configurable for different architectures
# AVX-512: 8, AVX2/NEON: 4, SSE2: 2
alias SIMD_WIDTH = 8  # Testing FMA on AVX-512
alias Vec = SIMD[DType.float64, SIMD_WIDTH]
alias BoolVec = SIMD[DType.bool, SIMD_WIDTH]

@always_inline
fn select_simd(cond: BoolVec, t: Vec, f: Vec) -> Vec:
    # Manual select using bitwise operations
    var mask = cond.cast[DType.int64]()
    mask = -mask
    var mask_u64 = mask.cast[DType.uint64]()
    var t_u64 = bitcast[DType.uint64, SIMD_WIDTH](t)
    var f_u64 = bitcast[DType.uint64, SIMD_WIDTH](f)
    var res_u64 = (t_u64 & mask_u64) | (f_u64 & ~mask_u64)
    return bitcast[DType.float64, SIMD_WIDTH](res_u64)

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
    
    var perige = a0dp * (1.0 - ecco) - 1.0
    var s = Vec(20.0 / KMPER)
    var s1_val = 78.0 / KMPER
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
    
    var q0 = 120.0 / KMPER
    var coef = ((q0 - s) * xi) ** 4.0
    var coef1 = coef / (sqrt(psisq) * psisq * psisq * psisq)
    
    var c1 = bstar * coef1 * n0dp * (
        a0dp * (1.0 + 1.5 * etasq + eeta * (4.0 + etasq))
        + 0.75 * CK2 * xi / psisq * x3thm1 * (8.0 + 3.0 * etasq * (8.0 + etasq))
    )
    
    var sini0 = sin(inclo)
    var omgdot = -1.5 * CK2 * x3thm1 * pinvsq * n0dp
    var xnodot = -1.5 * CK2 * cosi0 * pinvsq * n0dp
    var xmdot = 1.5 * CK2 * x3thm1 * pinvsq * (1.0 + 3.0 * theta2) * n0dp
    
    return SGP4Constants(
        n0dp, a0dp, ecco, inclo, nodeo, argpo, mo,
        omgdot, xnodot, xmdot, c1, sini0, cosi0
    )

@always_inline
fn fast_sin_cos_adaptive(x: Vec) -> Tuple[Vec, Vec]:
    """Width-generic fast math - force inline"""
    @parameter
    fn compute() -> Tuple[Vec, Vec]:
        return fast_sin_cos[SIMD_WIDTH](x)
    return compute()

@always_inline
fn sgp4_propagate_adaptive(c: SGP4Constants, tsince: Float64) -> Tuple[Vec, Vec, Vec, Vec, Vec, Vec]:
    var omega = c.argpo + c.omgdot * tsince
    var xnode = c.nodeo + c.xnodot * tsince
    var xmp = c.mo + c.xmdot * tsince
    
    var tsq = tsince * tsince
    var xnode_drag = xnode + c.xnodot * c.c1 * tsq
    var xmp_drag = xmp + c.n0dp * ((1.5 * c.c1 * tsq) + (c.c1 * c.c1 * tsq * tsince))
    var omega_drag = omega - (c.c1 * c.c1 * tsq * tsq * 0.5)
    
    # Kepler solver - manually unrolled for performance
    var e = xmp_drag
    
    # Iteration 1
    var sc = fast_sin_cos_adaptive(e)
    var sine = sc[0]
    var cose = sc[1]
    e = e - (e - c.ecco * sine - xmp_drag) / (1.0 - c.ecco * cose)
    
    # Iteration 2
    sc = fast_sin_cos_adaptive(e)
    sine = sc[0]
    cose = sc[1]
    e = e - (e - c.ecco * sine - xmp_drag) / (1.0 - c.ecco * cose)
    
    # Iteration 3
    sc = fast_sin_cos_adaptive(e)
    sine = sc[0]
    cose = sc[1]
    e = e - (e - c.ecco * sine - xmp_drag) / (1.0 - c.ecco * cose)
    
    var scE = fast_sin_cos_adaptive(e)
    var sinE = scE[0]
    var cosE = scE[1]
    var el2 = c.ecco * c.ecco
    var r = c.a0dp * (1.0 - c.ecco * cosE)
    
    var scOMG = fast_sin_cos_adaptive(omega_drag)
    var sinOMG = scOMG[0]
    var cosOMG = scOMG[1]
    var scNODE = fast_sin_cos_adaptive(xnode_drag)
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
    
    x = x * KMPER
    y = y * KMPER
    z = z * KMPER
    vx = vx * KMPER / 60.0
    vy = vy * KMPER / 60.0
    vz = vz * KMPER / 60.0
    
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
                
                var constants = sgp4_init_adaptive(
                    no_kozai.load[width=SIMD_WIDTH](j),
                    ecco.load[width=SIMD_WIDTH](j),
                    inclo.load[width=SIMD_WIDTH](j),
                    nodeo.load[width=SIMD_WIDTH](j),
                    argpo.load[width=SIMD_WIDTH](j),
                    mo.load[width=SIMD_WIDTH](j),
                    bstar.load[width=SIMD_WIDTH](j)
                )
                
                for t_idx in range(num_times):
                    var result = sgp4_propagate_adaptive(constants, times[t_idx])
                    var base_idx = t_idx * num_satellites * 6 + j
                    
                    mutable_results.store(base_idx + 0 * num_satellites, result[0])
                    mutable_results.store(base_idx + 1 * num_satellites, result[1])
                    mutable_results.store(base_idx + 2 * num_satellites, result[2])
                    mutable_results.store(base_idx + 3 * num_satellites, result[3])
                    mutable_results.store(base_idx + 4 * num_satellites, result[4])
                    mutable_results.store(base_idx + 5 * num_satellites, result[5])
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
