from builtin.simd import SIMD
from builtin.dtype import DType
from math import trunc, abs, floor
from memory import bitcast

# Constants for Cody-Waite Range Reduction (2*PI)
alias PI_A = 3.1415926218032836914
alias PI_B = 3.178650954705639e-08
alias PI_C = 1.2246467991473532e-16
alias TWO_PI = 6.28318530717958647692
alias INV_TWO_PI = 0.15915494309189533576
alias PI = 3.14159265358979323846

# Generic fast sin/cos for any SIMD width
@always_inline
fn fast_sin_cos[width: Int](x: SIMD[DType.float64, width]) -> Tuple[SIMD[DType.float64, width], SIMD[DType.float64, width]]:
    """
    Width-generic Degree 23/22 polynomial sin/cos approximation.
    Works for 2-wide (SSE2), 4-wide (AVX2/NEON), 8-wide (AVX-512), etc.
    Accuracy: ~1e-13
    """
    alias Vec = SIMD[DType.float64, width]
    
    # 1. Range Reduction to [-PI, PI]
    var k = floor(x * INV_TWO_PI + 0.5)
    var k_2 = k * 2.0
    var r = x - k_2 * PI_A
    r = r - k_2 * PI_B
    r = r - k_2 * PI_C
    
    # 2. Polynomial Approximation
    var r2 = r * r
    
    # Sin polynomial (Degree 23) - Horner's method
    var s11 = -3.8681701706306840377e-23
    var s10 =  1.9572941063391261231e-20
    var s9  = -8.2206352466243297170e-18
    var s8  =  2.8114572543455207632e-15
    var s7  = -7.6471637318198164759e-13
    var s6  =  1.6059043836821614599e-10
    var s5  = -2.5052108385441718775e-08
    var s4  =  2.7557319223985890653e-06
    var s3  = -1.9841269841269841270e-04
    var s2  =  8.3333333333333333333e-03
    var s1  = -1.6666666666666666667e-01
    
    var sin_val = Vec(s11)
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
    
    # Cos polynomial (Degree 22) - Horner's method
    var c11 = -8.8967913924505732867e-22
    var c10 =  4.1103176233121648585e-19
    var c9  = -1.5619206968586226462e-16
    var c8  =  4.7794773323873852974e-14
    var c7  = -1.1470745597729724714e-11
    var c6  =  2.0876756987868098979e-09
    var c5  = -2.7557319223985890653e-07
    var c4  =  2.4801587301587301587e-05
    var c3  = -1.3888888888888888889e-03
    var c2  =  4.1666666666666666667e-02
    var c1  = -5.0000000000000000000e-01
    
    var cos_val = Vec(c11)
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

# Convenience aliases for common widths
@always_inline
fn fast_sin_cos_sse2(x: SIMD[DType.float64, 2]) -> Tuple[SIMD[DType.float64, 2], SIMD[DType.float64, 2]]:
    """2-wide for SSE2"""
    return fast_sin_cos[2](x)

@always_inline
fn fast_sin_cos_avx2(x: SIMD[DType.float64, 4]) -> Tuple[SIMD[DType.float64, 4], SIMD[DType.float64, 4]]:
    """4-wide for AVX2 or ARM NEON"""
    return fast_sin_cos[4](x)

@always_inline
fn fast_sin_cos_avx512(x: SIMD[DType.float64, 8]) -> Tuple[SIMD[DType.float64, 8], SIMD[DType.float64, 8]]:
    """8-wide for AVX-512"""
    return fast_sin_cos[8](x)

# Individual sin/cos functions
@always_inline
fn fast_sin_avx512(x: SIMD[DType.float64, 8]) -> SIMD[DType.float64, 8]:
    var res = fast_sin_cos[8](x)
    return res[0]

@always_inline
fn fast_cos_avx512(x: SIMD[DType.float64, 8]) -> SIMD[DType.float64, 8]:
    var res = fast_sin_cos[8](x)
    return res[1]
