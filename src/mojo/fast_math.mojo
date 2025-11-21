from builtin.simd import SIMD
from builtin.dtype import DType
from math import trunc, abs, floor

alias Vec8 = SIMD[DType.float64, 8]

# Constants for Cody-Waite Range Reduction (2*PI)
# 2*PI = P1 + P2 + P3
alias P1 = 6.28318530717958623200e+00
alias P2 = 2.44929359829470635445e-16
alias P3 = 2.44929359829470635445e-16 # Placeholder, need better split if precision issues arise
# Actually, let's use the ones from before:
alias PI_A = 3.1415926218032836914
alias PI_B = 3.178650954705639e-08
alias PI_C = 1.2246467991473532e-16
alias TWO_PI = 6.28318530717958647692
alias INV_TWO_PI = 0.15915494309189533576

alias PI = 3.14159265358979323846

@always_inline
fn fast_sin_cos_avx512(x: Vec8) -> Tuple[Vec8, Vec8]:
    """
    Computes sin(x) and cos(x) using Range Reduction to [-PI, PI].
    Uses Degree 23/22 Polynomial.
    Accuracy: ~1e-13.
    """
    # 1. Range Reduction to k * 2*PI
    # k = round(x / (2*PI))
    var k = floor(x * INV_TWO_PI + 0.5)
    
    # x_red = x - k * 2*PI (Extended precision)
    var k_2 = k * 2.0
    var r = x - k_2 * PI_A
    r = r - k_2 * PI_B
    r = r - k_2 * PI_C
    
    # 2. Polynomial Approximation (Degree 23 for Sin, 22 for Cos)
    var r2 = r * r
    
    # Sin poly (Degree 23)
    # x - x^3/3! + x^5/5! - ... + x^23/23!
    # 1/3! = 0.16666666666666666667
    # ...
    # We can use Horner's method or precomputed powers.
    # Horner's is better for precision and fewer muls.
    # sin(x) = x * (1 + x^2 * (s1 + x^2 * (s2 + ...)))
    
    var s11 = -3.8681701706306840377e-23 # -1/23!
    var s10 =  1.9572941063391261231e-20 #  1/21!
    var s9  = -8.2206352466243297170e-18 # -1/19!
    var s8  =  2.8114572543455207632e-15 #  1/17!
    var s7  = -7.6471637318198164759e-13 # -1/15!
    var s6  =  1.6059043836821614599e-10 #  1/13!
    var s5  = -2.5052108385441718775e-08 # -1/11!
    var s4  =  2.7557319223985890653e-06 #  1/9!
    var s3  = -1.9841269841269841270e-04 # -1/7!
    var s2  =  8.3333333333333333333e-03 #  1/5!
    var s1  = -1.6666666666666666667e-01 # -1/3!
    
    var sin_val = Vec8(s11)
    sin_val = s10 + r2 * sin_val
    sin_val = s9  + r2 * sin_val
    sin_val = s8  + r2 * sin_val
    sin_val = s7  + r2 * sin_val
    sin_val = s6  + r2 * sin_val
    sin_val = s5  + r2 * sin_val
    sin_val = s4  + r2 * sin_val
    sin_val = s3  + r2 * sin_val
    sin_val = s2  + r2 * sin_val
    sin_val = s1  + r2 * sin_val
    sin_val = r * (1.0 + r2 * sin_val)
    
    # Cos poly (Degree 22)
    # 1 - x^2/2! + x^4/4! - ... + x^22/22!
    
    var c11 = -8.8967913924505732867e-22 # -1/22!
    var c10 =  4.1103176233121648585e-19 #  1/20!
    var c9  = -1.5619206968586226462e-16 # -1/18!
    var c8  =  4.7794773323873852974e-14 #  1/16!
    var c7  = -1.1470745597729724714e-11 # -1/14!
    var c6  =  2.0876756987868098979e-09 #  1/12!
    var c5  = -2.7557319223985890653e-07 # -1/10!
    var c4  =  2.4801587301587301587e-05 #  1/8!
    var c3  = -1.3888888888888888889e-03 # -1/6!
    var c2  =  4.1666666666666666667e-02 #  1/4!
    var c1  = -5.0000000000000000000e-01 # -1/2!
    
    var cos_val = Vec8(c11)
    cos_val = c10 + r2 * cos_val
    cos_val = c9  + r2 * cos_val
    cos_val = c8  + r2 * cos_val
    cos_val = c7  + r2 * cos_val
    cos_val = c6  + r2 * cos_val
    cos_val = c5  + r2 * cos_val
    cos_val = c4  + r2 * cos_val
    cos_val = c3  + r2 * cos_val
    cos_val = c2  + r2 * cos_val
    cos_val = c1  + r2 * cos_val
    cos_val = 1.0 + r2 * cos_val
    
    return (sin_val, cos_val)

@always_inline
fn fast_sin_avx512(x: Vec8) -> Vec8:
    var res = fast_sin_cos_avx512(x)
    return res[0]

@always_inline
fn fast_cos_avx512(x: Vec8) -> Vec8:
    var res = fast_sin_cos_avx512(x)
    return res[1]
