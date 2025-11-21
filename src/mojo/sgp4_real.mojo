"""
Real SGP4 Implementation in Mojo
Based on Spacetrack Report #3 and Vallado et al. (2006)
"""

from math import sin, cos, sqrt, atan2
from algorithm import parallelize
from memory import UnsafePointer

# SGP4 Constants
alias PI: Float64 = 3.141592653589793
alias TWOPI: Float64 = 6.283185307179586
alias DEG2RAD: Float64 = 0.017453292519943295
alias XKMPER: Float64 = 6378.137  # Earth radius in km
alias XKE: Float64 = 0.0743669161  # sqrt(GM) in earth radii^(3/2)/min
alias J2: Float64 = 0.00108262998905  # J2 harmonic
alias J3: Float64 = -0.00000253215306  # J3 harmonic
alias J4: Float64 = -0.00000161098761  # J4 harmonic
alias CK2: Float64 = 0.5 * J2
alias CK4: Float64 = -0.375 * J4
alias QOMS2T: Float64 = 1.88027916e-9  # (QOMS)^2
alias S: Float64 = 1.01222928  # S parameter
alias MINUTES_PER_DAY: Float64 = 1440.0

@always_inline
fn fabs(x: Float64) -> Float64:
    """Absolute value"""
    return x if x >= 0.0 else -x

@always_inline
fn fmod2p(x: Float64) -> Float64:
    """Modulo 2*PI"""
    var result = x
    while result < 0.0:
        result += TWOPI
    while result >= TWOPI:
        result -= TWOPI
    return result

@always_inline
fn actan(sinx: Float64, cosx: Float64) -> Float64:
    """Arctangent function that resolves quadrant"""
    if cosx == 0.0:
        if sinx > 0.0:
            return PI / 2.0
        else:
            return 3.0 * PI / 2.0
    elif cosx > 0.0:
        if sinx >= 0.0:
            return atan2(sinx, cosx)
        else:
            return atan2(sinx, cosx) + TWOPI
    else:
        return atan2(sinx, cosx) + PI

fn sgp4_real(
    tsince: Float64,
    no_kozai: Float64,  # Mean motion (rad/min)
    ecco: Float64,      # Eccentricity
    inclo: Float64,     # Inclination (rad)
    nodeo: Float64,     # Right ascension of ascending node (rad)
    argpo: Float64,     # Argument of perigee (rad)
    mo: Float64,        # Mean anomaly (rad)
    bstar: Float64,     # Drag term
    result_ptr: UnsafePointer[Float64],
    offset: Int
):
    """
    Real SGP4 propagation with perturbations
    Simplified version focusing on near-Earth orbits
    """
    
    # Mean motion (rad/min)
    var xno = no_kozai
    
    # Semi-major axis
    var a1 = (XKE / xno) ** (2.0/3.0)
    var cosio = cos(inclo)
    var theta2 = cosio * cosio
    var x3thm1 = 3.0 * theta2 - 1.0
    var eosq = ecco * ecco
    var betao2 = 1.0 - eosq
    var betao = sqrt(betao2)
    
    # For perigee less than 220 km, use simple drag model
    var del1 = 1.5 * CK2 * x3thm1 / (a1 * a1 * betao * betao2)
    var ao = a1 * (1.0 - del1 * (0.5 * (2.0/3.0) + del1 * (1.0 + 134.0/81.0 * del1)))
    var delo = 1.5 * CK2 * x3thm1 / (ao * ao * betao * betao2)
    var xnodp = xno / (1.0 + delo)  # Corrected mean motion
    var aodp = ao / (1.0 - delo)    # Corrected semi-major axis
    
    # Initialization
    var isimp = 0
    if (aodp * (1.0 - ecco) / XKMPER) < (220.0 / XKMPER + 1.0):
        isimp = 1
    
    # For simplicity, use secular perturbations only
    var s4 = S
    var qoms24 = QOMS2T
    var perige = (aodp * (1.0 - ecco) - 1.0) * XKMPER
    
    # Atmospheric drag coefficients
    var coef = qoms24 * ((s4 / aodp) ** 4.0)
    var coef1 = coef / (betao ** 8.0)
    
    var c2 = coef1 * xnodp * (aodp * (1.0 + 1.5 * eosq + eosq * ecco + ecco * (4.0 + eosq)) + 
                               0.75 * CK2 * (8.0 + 3.0 * theta2 * (8.0 + theta2)) / betao2)
    
    var c1 = bstar * c2
    var c3 = 0.0
    if ecco > 1.0e-4:
        c3 = coef * qoms24 * ((s4 / aodp) ** 4.0) * xnodp * (1.0 + ecco) * sin(argpo) / ecco
    
    var c4 = 2.0 * xnodp * coef1 * aodp * betao2 * (
        (2.0 * (7.0 * theta2 - 1.0) - 3.0 * ecco * ecco) / betao2 +
        2.0 * CK2 * (3.0 * (3.0 * theta2 - 1.0) * (1.0 + 1.5 * eosq) - 
                     0.75 * (1.0 - theta2) * (2.0 * eosq - 1.0) * cos(2.0 * argpo)) / betao2
    )
    
    var c5 = 2.0 * coef1 * aodp * betao2 * (1.0 + 2.75 * (eosq + ecco) + ecco * eosq)
    
    # Update for secular perturbations
    var xmdf = mo + xnodp * tsince
    var omgadf = argpo + c4 * tsince + c5 * (sin(xmdf) - sin(mo))
    var xnoddf = nodeo + c1 * tsince * tsince
    var omega = omgadf
    var xmp = xmdf
    
    var tsq = tsince * tsince
    var xnode = xnoddf + c1 * tsq
    var tempa = 1.0 - c1 * tsince
    var tempe = bstar * c4 * tsince
    var templ = c5 * tsince * tsince
    
    var a = aodp * tempa * tempa
    var e = ecco - tempe
    var xl = xmp + omega + xnode + xnodp * templ
    
    # Solve Kepler's equation
    var u = fmod2p(xl - xnode)
    var eo1 = u
    var tem5 = 9999.9
    var sineo1 = 0.0
    var coseo1 = 0.0
    
    # Newton-Raphson iteration for eccentric anomaly
    for _ in range(10):  # Max 10 iterations
        sineo1 = sin(eo1)
        coseo1 = cos(eo1)
        tem5 = 1.0 - coseo1 * a / aodp
        tem5 = (u - aodp * e * sineo1 / a + eo1 - xmp) / tem5
        if fabs(tem5) < 1.0e-12:
            break
        eo1 = eo1 - tem5
    
    # Short period preliminary quantities
    var ecose = a * e * coseo1 / aodp + e
    var esine = a * e * sineo1 / aodp
    var el2 = a * a / (aodp * aodp)
    var pl = a * (1.0 - el2)
    var r = a * (1.0 - ecose)
    var rdot = XKE * sqrt(a) * esine / r
    var rfdot = XKE * sqrt(pl) / r
    var temp = esine / (1.0 + sqrt(1.0 - el2))
    var betal = sqrt(1.0 - el2)
    var cosu = a / r * (coseo1 - e + e * temp)
    var sinu = a / r * (sineo1 - e * temp)
    var u_angle = actan(sinu, cosu)
    var sin2u = 2.0 * sinu * cosu
    var cos2u = 2.0 * cosu * cosu - 1.0
    
    # Update for short periodics
    var rk = r * (1.0 - 1.5 * CK2 * betal * (3.0 * theta2 - 1.0) / pl)
    var uk = u_angle - 0.25 * CK2 * (7.0 * theta2 - 1.0) * sin2u / pl
    var xnodek = xnode + 1.5 * CK2 * cosio * sin2u / pl
    var xinck = inclo + 1.5 * CK2 * cosio * sinu * sin2u / pl
    
    # Orientation vectors
    var sinuk = sin(uk)
    var cosuk = cos(uk)
    var sinik = sin(xinck)
    var cosik = cos(xinck)
    var sinnok = sin(xnodek)
    var cosnok = cos(xnodek)
    var xmx = -sinnok * cosik
    var xmy = cosnok * cosik
    var ux = xmx * sinuk + cosnok * cosuk
    var uy = xmy * sinuk + sinnok * cosuk
    var uz = sinik * sinuk
    
    # Position in km
    var x = rk * ux * XKMPER
    var y = rk * uy * XKMPER
    var z = rk * uz * XKMPER
    
    # Velocity in km/s
    var vx = (rdot * ux + rfdot * xmx) * XKMPER / 60.0
    var vy = (rdot * uy + rfdot * xmy) * XKMPER / 60.0
    var vz = (rdot * uz + rfdot * sinik) * XKMPER / 60.0
    
    # Store results
    var mut_ptr = result_ptr.unsafe_mut_cast[True]()
    mut_ptr.store(offset + 0, x)
    mut_ptr.store(offset + 1, y)
    mut_ptr.store(offset + 2, z)
    mut_ptr.store(offset + 3, vx)
    mut_ptr.store(offset + 4, vy)
    mut_ptr.store(offset + 5, vz)

fn propagate_sgp4_real(
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
    """Batch propagation with real SGP4"""
    
    @parameter
    fn worker(i: Int):
        sgp4_real(
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
