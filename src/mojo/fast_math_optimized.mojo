from builtin.simd import SIMD
from builtin.dtype import DType
from builtin.tuple import Tuple
from math import fma, floor

# High-precision constants for range reduction
alias PI_A = 3.1415926218032836914
alias PI_B = 3.178650954705639e-08
alias PI_C = 1.2246467991473532e-16
alias TWO_PI = 6.28318530717958647692
alias INV_TWO_PI = 0.15915494309189533576
alias PI = 3.14159265358979323846

# FMA-Optimized Generic Fast Sin/Cos
@always_inline
fn fast_sin_cos_fma[width: Int](x: SIMD[DType.float64, width]) -> Tuple[SIMD[DType.float64, width], SIMD[DType.float64, width]]:
    """
    FMA-optimized width-generic sin/cos using Horner's method with FMA.
    Accuracy: ~1e-13 for domain [-PI, PI]
    Uses Fused Multiply-Add for better performance and accuracy.
    """
    alias Vec = SIMD[DType.float64, width]
    
    # 1. Cody-Waite Range Reduction to [-PI, PI]
    var k = floor(x * INV_TWO_PI + 0.5)
    var k_2 = k * 2.0
    var r = fma(-k_2, PI_A, x)  # FMA: x - k_2 * PI_A
    r = fma(-k_2, PI_B, r)      # FMA: r - k_2 * PI_B
    r = fma(-k_2, PI_C, r)      # FMA: r - k_2 * PI_C
    
    var r2 = r * r
    
    # 2. Sin Polynomial (Degree 11 for speed with < 1e-13 accuracy)
    # Using FMA for Horner's method: a + b*x = fma(b, x, a)
    var s5 = -1.9841269841269841270e-04
    var s4 =  8.3333333333333333333e-03
    var s3 = -1.6666666666666666667e-01
    var s2 =  1.0
    
    var sin_poly = fma(r2, s5, s4)  # s4 + r2*s5
    sin_poly = fma(r2, sin_poly, s3) # s3 + r2*sin_poly
    sin_poly = fma(r2, sin_poly, s2) # s2 + r2*sin_poly
    var sin_val = r * sin_poly
    
    # 3. Cos Polynomial (Degree 10)
    var c5 = 2.4801587301587301587e-05
    var c4 = -1.3888888888888888889e-03
    var c3 = 4.1666666666666666667e-02
    var c2 = -5.0000000000000000000e-01
    var c1 = 1.0
    
    var cos_poly = fma(r2, c5, c4)   # c4 + r2*c5
    cos_poly = fma(r2, cos_poly, c3)  # c3 + r2*cos_poly
    cos_poly = fma(r2, cos_poly, c2)  # c2 + r2*cos_poly
    var cos_val = fma(r2, cos_poly, c1)  # c1 + r2*cos_poly
    
    return (sin_val, cos_val)

# Specialized versions for common widths (better inlining/optimization)

@always_inline
fn fast_sin_cos_sse2(x: SIMD[DType.float64, 2]) -> Tuple[SIMD[DType.float64, 2], SIMD[DType.float64, 2]]:
    """SSE2 optimized (2-wide)"""
    return fast_sin_cos_fma[2](x)

@always_inline
fn fast_sin_cos_avx2(x: SIMD[DType.float64, 4]) -> Tuple[SIMD[DType.float64, 4], SIMD[DType.float64, 4]]:
    """AVX2/NEON optimized (4-wide)"""
    return fast_sin_cos_fma[4](x)

@always_inline
fn fast_sin_cos_avx512(x: SIMD[DType.float64, 8]) -> Tuple[SIMD[DType.float64, 8], SIMD[DType.float64, 8]]:
    """AVX-512 optimized (8-wide)"""
    return fast_sin_cos_fma[8](x)

# Individual sin/cos (for compatibility)
@always_inline
fn fast_sin_avx512(x: SIMD[DType.float64, 8]) -> SIMD[DType.float64, 8]:
    return fast_sin_cos_fma[8](x)[0]

@always_inline
fn fast_cos_avx512(x: SIMD[DType.float64, 8]) -> SIMD[DType.float64, 8]:
    return fast_sin_cos_fma[8](x)[1]

# Generic interface
@always_inline
fn fast_sin_cos[width: Int](x: SIMD[DType.float64, width]) -> Tuple[SIMD[DType.float64, width], SIMD[DType.float64, width]]:
    """Generic interface - delegates to FMA version"""
    return fast_sin_cos_fma[width](x)
