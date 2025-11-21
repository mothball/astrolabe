from sys.intrinsics import prefetch, PrefetchOptions
from memory import UnsafePointer

fn main():
    var ptr = UnsafePointer[Float64].alloc(100)
    
    # Test prefetch with PrefetchOptions
    prefetch[PrefetchOptions().for_read().high_locality()](ptr)
    
    ptr.free()
    print("Prefetch with options works!")
