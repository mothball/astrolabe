from math import sin, cos
from algorithm import parallelize, vectorize
from memory import UnsafePointer

# OPTIMIZATION 1: Structure of Arrays (SoA) for better cache locality
# Instead of Array of Structs, use Struct of Arrays
struct SatelliteData:
    var count: Int
    var tsince_data: UnsafePointer[mut=True, Float64]  # All tsince values
    var result_x: UnsafePointer[mut=True, Float64]
    var result_y: UnsafePointer[mut=True, Float64]
    var result_z: UnsafePointer[mut=True, Float64]
    var result_vx: UnsafePointer[mut=True, Float64]
    var result_vy: UnsafePointer[mut=True, Float64]
    var result_vz: UnsafePointer[mut=True, Float64]
    
    fn __init__(out self, count: Int):
        self.count = count
        self.tsince_data = UnsafePointer[mut=True, Float64].alloc(count)
        self.result_x = UnsafePointer[mut=True, Float64].alloc(count)
        self.result_y = UnsafePointer[mut=True, Float64].alloc(count)
        self.result_z = UnsafePointer[mut=True, Float64].alloc(count)
        self.result_vx = UnsafePointer[mut=True, Float64].alloc(count)
        self.result_vy = UnsafePointer[mut=True, Float64].alloc(count)
        self.result_vz = UnsafePointer[mut=True, Float64].alloc(count)
        
        # Initialize tsince values
        for i in range(count):
            self.tsince_data[i] = 100.0
    
    fn free(self):
        self.tsince_data.free()
        self.result_x.free()
        self.result_y.free()
        self.result_z.free()
        self.result_vx.free()
        self.result_vy.free()
        self.result_vz.free()

# OPTIMIZATION 2: SIMD-vectorized propagation
fn propagate_simd(data: SatelliteData):
    alias simd_width = 4  # Process 4 Float64s at once (AVX2/AVX512)
    
    @parameter
    fn process_chunk(chunk_start: Int):
        # Process SIMD_WIDTH satellites at once
        @parameter
        fn simd_compute[width: Int](offset: Int):
            # Load tsince values for SIMD_WIDTH satellites
            var tsince = data.tsince_data.load[width=width](chunk_start + offset)
            
            # OPTIMIZATION 3: Compute sin/cos once, reuse
            var sin_t = sin(tsince)
            var cos_t = cos(tsince)
            
            # OPTIMIZATION 4: Inline all computations
            var x = sin_t * 7000.0
            var y = cos_t * 7000.0
            var vx = cos_t * 7.0
            var vy = sin_t * -7.0
            
            # Store results
            data.result_x.store(chunk_start + offset, x)
            data.result_y.store(chunk_start + offset, y)
            data.result_z.store(chunk_start + offset, 0.0)
            data.result_vx.store(chunk_start + offset, vx)
            data.result_vy.store(chunk_start + offset, vy)
            data.result_vz.store(chunk_start + offset, 0.0)
        
        # Vectorize within each chunk
        vectorize[simd_compute, simd_width](simd_width)
    
    # OPTIMIZATION 5: Parallelize across chunks
    var num_chunks = data.count // simd_width
    parallelize[process_chunk](num_chunks, num_chunks)
    
    # Handle remainder
    var remainder_start = num_chunks * simd_width
    for i in range(remainder_start, data.count):
        var tsince = data.tsince_data[i]
        var sin_t = sin(tsince)
        var cos_t = cos(tsince)
        
        data.result_x[i] = sin_t * 7000.0
        data.result_y[i] = cos_t * 7000.0
        data.result_z[i] = 0.0
        data.result_vx[i] = cos_t * 7.0
        data.result_vy[i] = sin_t * -7.0
        data.result_vz[i] = 0.0
