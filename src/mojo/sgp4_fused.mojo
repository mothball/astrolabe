"""
EXPRESSION FUSION - Heyoka-Style Mega-Expression
Uses Mojo's @parameter to fuse all operations at compile time
"""

from math import sin, cos, sqrt, atan2
from algorithm import parallelize
from memory import UnsafePointer

# SGP4 Constants
alias PI: Float64 = 3.141592653589793
alias TWOPI: Float64 = 6.283185307179586
alias DEG2RAD: Float64 = 0.017453292519943295
alias XKMPER: Float64 = 6378.137
alias XKE: Float64 = 0.0743669161
alias J2: Float64 = 0.00108262998905
alias CK2: Float64 = 0.5 * J2
alias CK4: Float64 = -0.375 * (-0.00000161098761)
alias QOMS2T: Float64 = 1.88027916e-9
alias S: Float64 = 1.01222928

@always_inline
fn fmod2p_fused(x: Float64) -> Float64:
    """Fused modulo 2*PI - single expression"""
    return x - TWOPI * Float64(Int(x / TWOPI)) + (TWOPI if x < 0.0 else 0.0)

@always_inline
fn actan_fused(sinx: Float64, cosx: Float64) -> Float64:
    """Fused arctangent - single expression"""
    return (
        PI / 2.0 if (cosx == 0.0 and sinx > 0.0) else
        3.0 * PI / 2.0 if (cosx == 0.0) else
        atan2(sinx, cosx) if (cosx > 0.0 and sinx >= 0.0) else
        atan2(sinx, cosx) + TWOPI if (cosx > 0.0) else
        atan2(sinx, cosx) + PI
    )

@always_inline
fn sgp4_mega_expression(
    tsince: Float64,
    xno: Float64,
    ecco: Float64,
    inclo: Float64,
    nodeo: Float64,
    argpo: Float64,
    mo: Float64,
    bstar: Float64,
    result_ptr: UnsafePointer[Float64],
    offset: Int
):
    """
    MEGA-EXPRESSION: Entire SGP4 as one fused computation
    All intermediate values computed inline
    LLVM can optimize the entire expression tree
    """
    
    # Precompute trig functions (can't avoid these)
    var cosio = cos(inclo)
    var theta2 = cosio * cosio
    
    # FUSED EXPRESSION BLOCK 1: Semi-major axis with drag
    var a1 = (XKE / xno) ** (2.0/3.0)
    var eosq = ecco * ecco
    var betao2 = 1.0 - eosq
    var betao = sqrt(betao2)
    var x3thm1 = 3.0 * theta2 - 1.0
    
    var aodp = (
        a1 * (1.0 - 
            1.5 * CK2 * x3thm1 / (a1 * a1 * betao * betao2) * 
            (0.5 * (2.0/3.0) + 
             1.5 * CK2 * x3thm1 / (a1 * a1 * betao * betao2) * 
             (1.0 + 134.0/81.0 * 1.5 * CK2 * x3thm1 / (a1 * a1 * betao * betao2)))
        ) / (1.0 - 1.5 * CK2 * x3thm1 / (
            (a1 * (1.0 - 1.5 * CK2 * x3thm1 / (a1 * a1 * betao * betao2) * 
             (0.5 * (2.0/3.0) + 1.5 * CK2 * x3thm1 / (a1 * a1 * betao * betao2) * 
              (1.0 + 134.0/81.0 * 1.5 * CK2 * x3thm1 / (a1 * a1 * betao * betao2))))) * 
            (a1 * (1.0 - 1.5 * CK2 * x3thm1 / (a1 * a1 * betao * betao2) * 
             (0.5 * (2.0/3.0) + 1.5 * CK2 * x3thm1 / (a1 * a1 * betao * betao2) * 
              (1.0 + 134.0/81.0 * 1.5 * CK2 * x3thm1 / (a1 * a1 * betao * betao2))))) * 
            betao * betao2))
    )
    
    # This is getting too complex - let's use a hybrid approach
    # Fuse within logical blocks, but keep blocks separate
    
    # BLOCK 1: Drag coefficients (fused)
    var coef = QOMS2T * ((S / aodp) ** 4.0)
    var coef1 = coef / (betao ** 8.0)
    var xnodp = xno / (1.0 + 1.5 * CK2 * x3thm1 / (aodp * aodp * betao * betao2))
    
    var c2 = coef1 * xnodp * (aodp * (1.0 + 1.5 * eosq + eosq * ecco + ecco * (4.0 + eosq)) + 
                               0.75 * CK2 * (8.0 + 3.0 * theta2 * (8.0 + theta2)) / betao2)
    var c1 = bstar * c2
    var c4 = 2.0 * xnodp * coef1 * aodp * betao2 * (
        (2.0 * (7.0 * theta2 - 1.0) - 3.0 * ecco * ecco) / betao2 +
        2.0 * CK2 * (3.0 * (3.0 * theta2 - 1.0) * (1.0 + 1.5 * eosq) - 
                     0.75 * (1.0 - theta2) * (2.0 * eosq - 1.0) * cos(2.0 * argpo)) / betao2
    )
    var c5 = 2.0 * coef1 * aodp * betao2 * (1.0 + 2.75 * (eosq + ecco) + ecco * eosq)
    
    # BLOCK 2: Secular perturbations (fused)
    var xmdf = mo + xnodp * tsince
    var sin_xmdf = sin(xmdf)
    var sin_mo = sin(mo)
    var tsq = tsince * tsince
    
    var a = aodp * (1.0 - c1 * tsince) * (1.0 - c1 * tsince)
    var e = ecco - bstar * c4 * tsince
    var xl = xmdf + argpo + c4 * tsince + c5 * (sin_xmdf - sin_mo) + nodeo + c1 * tsq + xnodp * c5 * tsq
    var xnode = nodeo + c1 * tsq + c1 * tsq
    
    # BLOCK 3: Kepler solver (fused iterations)
    var u = fmod2p_fused(xl - xnode)
    var eo1 = u
    
    # Fused Newton-Raphson (3 iterations)
    eo1 = eo1 - (u - aodp * e * sin(eo1) / a + eo1 - xmdf) / (1.0 - cos(eo1) * a / aodp)
    eo1 = eo1 - (u - aodp * e * sin(eo1) / a + eo1 - xmdf) / (1.0 - cos(eo1) * a / aodp)
    eo1 = eo1 - (u - aodp * e * sin(eo1) / a + eo1 - xmdf) / (1.0 - cos(eo1) * a / aodp)
    
    var sineo1 = sin(eo1)
    var coseo1 = cos(eo1)
    
    # BLOCK 4: Position/velocity (mega-fused expression)
    var el2 = a * a / (aodp * aodp)
    var betal = sqrt(1.0 - el2)
    var pl = a * (1.0 - el2)
    var r = a * (1.0 - (a * e * coseo1 / aodp + e))
    
    var esine = a * e * sineo1 / aodp
    var temp = esine / (1.0 + betal)
    var cosu = a / r * (coseo1 - e + e * temp)
    var sinu = a / r * (sineo1 - e * temp)
    var u_angle = actan_fused(sinu, cosu)
    var sin2u = 2.0 * sinu * cosu
    
    # BLOCK 5: Final transformation (fused)
    var rk = r * (1.0 - 1.5 * CK2 * betal * (3.0 * theta2 - 1.0) / pl)
    var uk = u_angle - 0.25 * CK2 * (7.0 * theta2 - 1.0) * sin2u / pl
    var xnodek = xnode + 1.5 * CK2 * cosio * sin2u / pl
    var xinck = inclo + 1.5 * CK2 * cosio * sinu * sin2u / pl
    
    var sinuk = sin(uk)
    var cosuk = cos(uk)
    var sinik = sin(xinck)
    var cosik = cos(xinck)
    var sinnok = sin(xnodek)
    var cosnok = cos(xnodek)
    
    # MEGA-FUSED FINAL EXPRESSION
    var xmx = -sinnok * cosik
    var xmy = cosnok * cosik
    var rdot = XKE * sqrt(a) * esine / r
    var rfdot = XKE * sqrt(pl) / r
    
    # Store results (fused position/velocity computation)
    var mut_ptr = result_ptr.unsafe_mut_cast[True]()
    mut_ptr.store(offset + 0, rk * (xmx * sinuk + cosnok * cosuk) * XKMPER)
    mut_ptr.store(offset + 1, rk * (xmy * sinuk + sinnok * cosuk) * XKMPER)
    mut_ptr.store(offset + 2, rk * sinik * sinuk * XKMPER)
    mut_ptr.store(offset + 3, (rdot * (xmx * sinuk + cosnok * cosuk) + rfdot * xmx) * XKMPER / 60.0)
    mut_ptr.store(offset + 4, (rdot * (xmy * sinuk + sinnok * cosuk) + rfdot * xmy) * XKMPER / 60.0)
    mut_ptr.store(offset + 5, (rdot * sinik * sinuk + rfdot * sinik) * XKMPER / 60.0)

fn propagate_fused(
    no_kozai_arr: UnsafePointer[Float64],
    ecco_arr: UnsafePointer[Float64],
    inclo_arr: UnsafePointer[Float64],
    nodeo_arr: UnsafePointer[Float64],
    argpo_arr: UnsafePointer[Float64],
    mo_arr: UnsafePointer[Float64],
    bstar_arr: UnsafePointer[Float64],
    results: UnsafePointer[Float64],
    count: Int,
    tsince: Float64
):
    """Propagation with fused expressions"""
    
    @parameter
    fn worker(i: Int):
        sgp4_mega_expression(
            tsince,
            no_kozai_arr[i],
            ecco_arr[i],
            inclo_arr[i],
            nodeo_arr[i],
            argpo_arr[i],
            mo_arr[i],
            bstar_arr[i],
            results,
            i * 6
        )
    
    parallelize[worker](count, count)

fn propagate_fused_batch(
    no_kozai_arr: UnsafePointer[Float64],
    ecco_arr: UnsafePointer[Float64],
    inclo_arr: UnsafePointer[Float64],
    nodeo_arr: UnsafePointer[Float64],
    argpo_arr: UnsafePointer[Float64],
    mo_arr: UnsafePointer[Float64],
    bstar_arr: UnsafePointer[Float64],
    times: UnsafePointer[Float64],
    num_times: Int,
    results: UnsafePointer[Float64],
    num_satellites: Int
):
    """Batch-mode with fused expressions"""
    
    @parameter
    fn worker(time_idx: Int):
        var tsince = times[time_idx]
        var time_offset = time_idx * 6 * num_satellites
        
        for sat_idx in range(num_satellites):
            sgp4_mega_expression(
                tsince,
                no_kozai_arr[sat_idx],
                ecco_arr[sat_idx],
                inclo_arr[sat_idx],
                nodeo_arr[sat_idx],
                argpo_arr[sat_idx],
                mo_arr[sat_idx],
                bstar_arr[sat_idx],
                results,
                time_offset + sat_idx * 6
            )
    
    parallelize[worker](num_times, num_times)
