from math import sin, cos, sqrt
from algorithm import parallelize
from memory import UnsafePointer, bitcast
from sys.intrinsics import prefetch, PrefetchOptions
from builtin.simd import SIMD
from builtin.dtype import DType
from builtin.tuple import Tuple

# Constants (always compute in highest precision, cast as needed)
alias KMPER_F64: Float64 = 6378.135
alias KE_F64: Float64 = 0.07436691613317342
alias TOTHRD_F64: Float64 = 2.0 / 3.0
alias J2_F64: Float64 = 1.082616e-3
alias CK2_F64: Float64 = 0.5 * J2_F64
alias DEG2RAD_F64: Float64 = 0.017453292519943295

# Precision modes
alias PRECISION_FP64 = 0
alias PRECISION_FP32 = 1
alias PRECISION_MIXED = 2

# Kepler solver modes
alias KEPLER_NEWTON = 0
alias KEPLER_HALLEY = 1
alias KEPLER_ADAPTIVE = 2

@always_inline
fn select_simd[T: DType, S: Int](cond: SIMD[DType.bool, S], t: SIMD[T, S], f: SIMD[T, S]) -> SIMD[T, S]:
    var mask = cond.cast[DType.int64](

)
    mask = -mask
    var mask_u = mask.cast[DType.uint64]()
    var t_u = bitcast[DType.uint64, S](t)
    var f_u = bitcast[DType.uint64, S](f)
    var res_u = (t_u & mask_u) | (f_u & ~mask_u)
    return bitcast[T, S](res_u)

struct SGP4Constants[T: DType, S: Int](Copyable, Movable, ImplicitlyCopyable):
    var n0dp: SIMD[T, S]
    var a0dp: SIMD[T, S]
    var ecco: SIMD[T, S]
    var inclo: SIMD[T, S]
    var nodeo: SIMD[T, S]
    var argpo: SIMD[T, S]
    var mo: SIMD[T, S]
    var omgdot: SIMD[T, S]
    var xnodot: SIMD[T, S]
    var xmdot: SIMD[T, S]
    var c1: SIMD[T, S]
    var sinio: SIMD[T, S]
    var cosio: SIMD[T, S]

    fn __init__(
        out self, n0dp: SIMD[T, S], a0dp: SIMD[T, S], ecco: SIMD[T, S], inclo: SIMD[T, S],
        nodeo: SIMD[T, S], argpo: SIMD[T, S], mo: SIMD[T, S], omgdot: SIMD[T, S], 
        xnodot: SIMD[T, S], xmdot: SIMD[T, S], c1: SIMD[T, S], sinio: SIMD[T, S], cosio: SIMD[T, S]
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
fn sgp4_init[T: DType, S: Int](
    no_kozai: SIMD[T, S], ecco: SIMD[T, S], inclo: SIMD[T, S], nodeo: SIMD[T, S],
    argpo: SIMD[T, S], mo: SIMD[T, S], bstar: SIMD[T, S]
) -> SGP4Constants[T, S]:
    alias KMPER = SIMD[T, S](KMPER_F64)
    alias KE = SIMD[T, S](KE_F64)
    alias TOTHRD = SIMD[T, S](TOTHRD_F64)
    alias CK2 = SIMD[T, S](CK2_F64)
    
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
    var s = SIMD[T, S](20.0 / KMPER_F64)
    var s1_val = SIMD[T, S](78.0 / KMPER_F64)
    var s_cond = perige - s1_val
    
    s = select_simd(s_cond.lt(0.0), s_cond, s)
    s = select_simd(s.lt(s1_val), s1_val, s)
    
    var s4 = 1.0 + s
    var pinvsq = 1.0 / ((a0dp * beta02) ** 2.0)
    var xi = 1.0 / (a0dp - s4)
    var eta = a0dp * xi * ecco
    var etasq = eta * eta
    var eeta = ecco * eta
    var psisq = abs(1.0 - etasq)
    
    var q0 = SIMD[T, S](120.0 / KMPER_F64)
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
    
    return SGP4Constants[T, S](
        n0dp, a0dp, ecco, inclo, nodeo, argpo, mo,
        omgdot, xnodot, xmdot, c1, sini0, cosi0
    )

@always_inline
fn kepler_newton[T: DType, S: Int](
    e_val: SIMD[T, S], M: SIMD[T, S], iterations: Int
) -> SIMD[T, S]:
    """Standard Newton-Raphson Kepler solver"""
    var E = M
    for _ in range(iterations):
        var sinE = sin(E)
        var cosE = cos(E)
        E = E - (E - e_val * sinE - M) / (1.0 - e_val * cosE)
    return E

@always_inline
fn kepler_halley[T: DType, S: Int](
    e_val: SIMD[T, S], M: SIMD[T, S]
) -> SIMD[T, S]:
    """Halley's method - 3rd order convergence (2 iterations vs 3 for Newton)"""
    var E = M  # Initial guess
    
    # Iteration 1
    var sinE = sin(E)
    var cosE = cos(E)
    var f = E - e_val * sinE - M
    var fp = 1.0 - e_val * cosE
    var fpp = e_val * sinE
    E = E - (2.0 * f * fp) / (2.0 * fp * fp - f * fpp)
    
    # Iteration 2
    sinE = sin(E)
    cosE = cos(E)
    f = E - e_val * sinE - M
    fp = 1.0 - e_val * cosE
    fpp = e_val * sinE
    E = E - (2.0 * f * fp) / (2.0 * fp * fp - f * fpp)
    
    return E

@always_inline
fn kepler_adaptive[T: DType, S: Int](
    e_val: SIMD[T, S], M: SIMD[T, S]
) -> SIMD[T, S]:
    """Adaptive iterations based on eccentricity"""
    var E = M
    
    # Always do 1 iteration
    var sinE = sin(E)
    var cosE = cos(E)
    E = E - (E - e_val * sinE - M) / (1.0 - e_val * cosE)
    
    # Second iteration
    sinE = sin(E)
    cosE = cos(E)
    E = E - (E - e_val * sinE - M) / (1.0 - e_val * cosE)
    
    # Third iteration only for high eccentricity (e > 0.01)
    var high_ecc = e_val.gt(0.01)
    var E_iter3 = E
    sinE = sin(E_iter3)
    cosE = cos(E_iter3)
    E_iter3 = E_iter3 - (E_iter3 - e_val * sinE - M) / (1.0 - e_val * cosE)
    
    E = select_simd(high_ecc, E_iter3, E)
    return E

@always_inline
fn sgp4_propagate[
    T: DType, S: Int, KEPLER_MODE: Int
](c: SGP4Constants[T, S], tsince: Float64) -> Tuple[SIMD[T, S], SIMD[T, S], SIMD[T, S], SIMD[T, S], SIMD[T, S], SIMD[T, S]]:
    alias KMPER = SIMD[T, S](KMPER_F64)
    alias CK2 = SIMD[T, S](CK2_F64)
    
    var t = SIMD[T, S](tsince)
    var omega = c.argpo + c.omgdot * t
    var xnode = c.nodeo + c.xnodot * t
    var xmp = c.mo + c.xmdot * t
    
    var tsq = t * t
    var xnode_drag = xnode + c.xnodot * c.c1 * tsq
    var xmp_drag = xmp + c.n0dp * ((1.5 * c.c1 * tsq) + (c.c1 * c.c1 * tsq * t))
    var omega_drag = omega - (c.c1 * c.c1 * tsq * tsq * 0.5)
    
    # Kepler solver - select based on mode
    var E: SIMD[T, S]
    
    @parameter
    if KEPLER_MODE == KEPLER_HALLEY:
        E = kepler_halley[T, S](c.ecco, xmp_drag)
    elif KEPLER_MODE == KEPLER_ADAPTIVE:
        E = kepler_adaptive[T, S](c.ecco, xmp_drag)
    else:  # KEPLER_NEWTON
        E = kepler_newton[T, S](c.ecco, xmp_drag, 3)
    
    var sinE = sin(E)
    var cosE = cos(E)
    var el2 = c.ecco * c.ecco
    var r = c.a0dp * (1.0 - c.ecco * cosE)
    
    var sinOMG = sin(omega_drag)
    var cosOMG = cos(omega_drag)
    var sinNODE = sin(xnode_drag)
    var cosNODE = cos(xnode_drag)
    
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

fn propagate_batch[
    T: DType, S: Int, KEPLER_MODE: Int
](
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
        
        for j in range(start, end, S):
            if j + S <= end:
                # Load data and cast to target precision
                var no_f64 = no_kozai.load[width=S](j)
                var e_f64 = ecco.load[width=S](j)
                var i_f64 = inclo.load[width=S](j)
                var node_f64 = nodeo.load[width=S](j)
                var omega_f64 = argpo.load[width=S](j)
                var m_f64 = mo.load[width=S](j)
                var bstar_f64 = bstar.load[width=S](j)
                
                var no_t = no_f64.cast[T]()
                var e_t = e_f64.cast[T]()
                var i_t = i_f64.cast[T]()
                var node_t = node_f64.cast[T]()
                var omega_t = omega_f64.cast[T]()
                var m_t = m_f64.cast[T]()
                var bstar_t = bstar_f64.cast[T]()
                
                var constants = sgp4_init[T, S](no_t, e_t, i_t, node_t, omega_t, m_t, bstar_t)
                
                for t_idx in range(num_times):
                    var result = sgp4_propagate[T, S, KEPLER_MODE](constants, times[t_idx])
                    var base_idx = t_idx * num_satellites * 6 + j
                    
                    # Cast results back to FP64 for storage
                    mutable_results.store(base_idx + 0 * num_satellites, result[0].cast[DType.float64]())
                    mutable_results.store(base_idx + 1 * num_satellites, result[1].cast[DType.float64]())
                    mutable_results.store(base_idx + 2 * num_satellites, result[2].cast[DType.float64]())
                    mutable_results.store(base_idx + 3 * num_satellites, result[3].cast[DType.float64]())
                    mutable_results.store(base_idx + 4 * num_satellites, result[4].cast[DType.float64]())
                    mutable_results.store(base_idx + 5 * num_satellites, result[5].cast[DType.float64]())
    
    parallelize[worker](num_satellites // 4096 + 1, 32)
