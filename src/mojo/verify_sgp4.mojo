from math import sin, cos, sqrt
from builtin.simd import SIMD
from builtin.dtype import DType
from random import seed, random_float64
from memory import UnsafePointer

# Import the implementation to test
from sgp4_two_phase import sgp4_init_avx512, sgp4_propagate_avx512, SGP4Constants
from fast_math import fast_sin_cos_avx512

alias Vec8 = SIMD[DType.float64, 8]

# Reference Implementation (Scalar, High Precision, High Iterations)
fn solve_kepler_ref(M: Float64, e: Float64) -> Float64:
    var E = M
    for _ in range(20): # High iterations for ground truth
        var sinE = sin(E)
        var cosE = cos(E)
        var f = E - e * sinE - M
        var f_prime = 1.0 - e * cosE
        E = E - f / f_prime
        if abs(f) < 1e-12:
            break
    return E

fn sgp4_propagate_ref(c: SGP4Constants, tsince: Float64, idx: Int) -> Float64:
    # Extract scalar constants
    var ecco = c.ecco[idx]
    var argpo = c.argpo[idx]
    var omgdot = c.omgdot[idx]
    var nodeo = c.nodeo[idx]
    var xnodot = c.xnodot[idx]
    var mo = c.mo[idx]
    var xmdot = c.xmdot[idx]
    var c1 = c.c1[idx]
    var n0dp = c.n0dp[idx]
    var a0dp = c.a0dp[idx]
    var sinio = c.sinio[idx]
    var cosio = c.cosio[idx]
    
    # Time propagation
    var omega = argpo + omgdot * tsince
    var xnode = nodeo + xnodot * tsince
    var xmp = mo + xmdot * tsince
    
    # Secular drag effects
    var tsq = tsince * tsince
    var xnode_drag = xnode + xnodot * c1 * tsq
    var xmp_drag = xmp + n0dp * ((1.5 * c1 * tsq) + (c1 * c1 * tsq * tsince))
    var omega_drag = omega - (c1 * c1 * tsq * tsq * 0.5)
    
    # Solve Kepler
    var E = solve_kepler_ref(xmp_drag, ecco)
    
    # Short period
    var sinE = sin(E)
    var cosE = cos(E)
    var ecosE = ecco * cosE
    var esinE = ecco * sinE
    var el2 = ecco * ecco
    var pl = a0dp * (1.0 - el2)
    var r = a0dp * (1.0 - ecosE)
    var rdot = sqrt(a0dp) * esinE / r
    var rfdot = sqrt(pl) / r
    
    var u = a0dp * (cosE - ecco)
    var v = a0dp * sqrt(1.0 - el2) * sinE
    
    var sinOMG = sin(omega_drag)
    var cosOMG = cos(omega_drag)
    var sinNODE = sin(xnode_drag)
    var cosNODE = cos(xnode_drag)
    var sini = sinio
    var cosi = cosio
    
    var x = u * (cosNODE * cosOMG - sinNODE * sinOMG * cosi) - v * (cosNODE * sinOMG + sinNODE * cosOMG * cosi)
    
    # Scale to km
    var KMPER = 6378.135
    x = x * KMPER
    
    return x # Just return X for comparison

fn main() raises:
    print("============================================================")
    print("VERIFYING SGP4 SOLVER ACCURACY")
    print("============================================================")
    
    # Initialize random data
    var n0 = Vec8(0.05)
    var e0 = Vec8(0.001) # Low eccentricity
    var i0 = Vec8(0.5)
    var node0 = Vec8(0.1)
    var omega0 = Vec8(0.2)
    var m0 = Vec8(0.3)
    var bstar = Vec8(0.0001)
    
    var c = sgp4_init_avx512(n0, e0, i0, node0, omega0, m0, bstar)
    var tsince = 100.0
    
    # Run Optimized
    var res_opt = sgp4_propagate_avx512(c, tsince)
    var x_opt = res_opt[0]
    
    # Run Reference (Scalar loop)
    var max_err = 0.0
    for i in range(8):
        var ref_val = sgp4_propagate_ref(c, tsince, i)
        var opt_val = x_opt[i]
        var err = abs(ref_val - opt_val)
        if err > max_err:
            max_err = err
            
    print("Low Eccentricity Error: ", max_err)
    
    # High Eccentricity Test
    var e_high = Vec8(0.1) # Higher eccentricity
    var c_high = sgp4_init_avx512(n0, e_high, i0, node0, omega0, m0, bstar)
    
    var res_high = sgp4_propagate_avx512(c_high, tsince)
    var x_high = res_high[0]
    
    max_err = 0.0
    for i in range(8):
        var ref_val = sgp4_propagate_ref(c_high, tsince, i)
        var opt_val = x_high[i]
        var err = abs(ref_val - opt_val)
        if err > max_err:
            max_err = err
            
    print("High Eccentricity Error: ", max_err)
    
    if max_err < 1e-7: # SGP4 is approx model, but solver diff should be small
        print("✓ SGP4 Verification PASSED")
    else:
        print("✗ SGP4 Verification FAILED")
