from fast_math import fast_sin_cos_avx512, PI, TWO_PI
from math import sin, cos
from builtin.simd import SIMD
from builtin.dtype import DType
from random import random_float64

alias Vec8 = SIMD[DType.float64, 8]

fn main() raises:
    print("============================================================")
    print("VERIFYING FAST MATH ACCURACY")
    print("============================================================")
    
    var max_sin_error = 0.0
    var max_cos_error = 0.0
    var iterations = 100000
    
    for i in range(iterations):
        # Generate random inputs in range [-100 PI, 100 PI] to test range reduction
        var val = (random_float64() - 0.5) * 200.0 * PI
        var vec = Vec8(val) # Broadcast to vector
        
        # Fast Math
        var res = fast_sin_cos_avx512(vec)
        var fast_s = res[0]
        var fast_c = res[1]
        
        # Standard Math (scalar check on first element)
        var std_s = sin(val)
        var std_c = cos(val)
        
        # Check error on first element
        var err_s = abs(fast_s[0] - std_s)
        var err_c = abs(fast_c[0] - std_c)
        
        if err_s > max_sin_error:
            max_sin_error = err_s
        if err_c > max_cos_error:
            max_cos_error = err_c
            
    print("Iterations:", iterations)
    print("Max Sin Error:", max_sin_error)
    print("Max Cos Error:", max_cos_error)
    
    if max_sin_error < 1e-9 and max_cos_error < 1e-9:
        print("✓ Accuracy Check PASSED (Error < 1e-9)")
    else:
        print("✗ Accuracy Check FAILED (Error >= 1e-9)")
