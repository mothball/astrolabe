from math import sin, cos
from builtin.simd import SIMD
from builtin.dtype import DType
from builtin.tuple import Tuple
from memory import UnsafePointer

# LUT-based trigonometry
alias LUT_SIZE = 512
alias LUT_SIZE_F64 = Float64(LUT_SIZE)
alias TWO_PI = 6.283185307179586

# Pre-computed sin table (will be initialized at module load)
struct SinLUT:
    var table: UnsafePointer[Float64]
    
    fn __init__(out self):
        self.table = UnsafePointer[Float64].alloc(LUT_SIZE)
        # Initialize table
        for i in range(LUT_SIZE):
            var angle = Float64(i) * TWO_PI / LUT_SIZE_F64
            self.table[i] = sin(angle)
    
    fn __del__(owned self):
        self.table.free()

# Global LUT instance (initialized once)
var _sin_lut: SinLUT

fn init_lut():
    """Initialize the global sin LUT"""
    _sin_lut = SinLUT()

@always_inline
fn lut_sin_cos[width: Int](x: SIMD[DType.float64, width]) -> Tuple[SIMD[DType.float64, width], SIMD[DType.float64, width]]:
    """
    Fast sin/cos using lookup table with linear interpolation
    
    Trade-off: ~2-3x faster than polynomial, but ~1e-4 accuracy vs 1e-15
    """
    alias INV_TWO_PI = 1.0 / TWO_PI
    alias HALF_PI = 1.5707963267948966
    
    # Range reduction to [0, 2π]
    var normalized = x * INV_TWO_PI
    normalized = normalized - floor(normalized)
    var angle_norm = normalized * TWO_PI
    
    # Convert to table index (float)
    var idx_f = angle_norm * LUT_SIZE_F64 * INV_TWO_PI
    var idx = idx_f.cast[DType.int64]()
    
    # Linear interpolation
    var idx_next = (idx + 1) % LUT_SIZE
    var frac = idx_f - idx.cast[DType.float64]()
    
    # Lookup (scalar for now, could vectorize with gather)
    var sin_val = SIMD[DType.float64, width](0.0)
    var cos_val = SIMD[DType.float64, width](0.0)
    
    @parameter
    for i in range(width):
        var i0 = int(idx[i])
        var i1 = int(idx_next[i])
        var f = frac[i]
        
        # Sin interpolation
        var s0 = _sin_lut.table[i0]
        var s1 = _sin_lut.table[i1]
        sin_val[i] = s0 + f * (s1 - s0)
        
        # Cos from identity: cos(x) = sin(x + π/2)
        var cos_idx_f = (angle_norm[i] + HALF_PI) * LUT_SIZE_F64 / TWO_PI
        var ci0 = int(cos_idx_f) % LUT_SIZE
        var ci1 = (ci0 + 1) % LUT_SIZE
        var cf = cos_idx_f - floor(cos_idx_f)
        
        var c0 = _sin_lut.table[ci0]
        var c1 = _sin_lut.table[ci1]
        cos_val[i] = c0 + cf * (c1 - c0)
    
    return (sin_val, cos_val)
