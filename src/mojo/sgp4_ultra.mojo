from math import sin, cos
from algorithm import parallelize
from memory import UnsafePointer

fn propagate_ultra(results: UnsafePointer[Float64], count: Int, tsince: Float64):
    """Ultra-optimized batch propagation - same as original but cleaner"""
    
    var mut_results = results.unsafe_mut_cast[True]()
    
    @parameter
    fn worker(i: Int):
        # Compute sin/cos once per satellite
        var sin_t = sin(tsince)
        var cos_t = cos(tsince)
        
        var offset = i * 6
        
        # Direct stores
        mut_results.store(offset + 0, sin_t * 7000.0)
        mut_results.store(offset + 1, cos_t * 7000.0)
        mut_results.store(offset + 2, 0.0)
        mut_results.store(offset + 3, cos_t * 7.0)
        mut_results.store(offset + 4, sin_t * -7.0)
        mut_results.store(offset + 5, 0.0)
    
    parallelize[worker](count, count)
