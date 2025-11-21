from sgp4_ultra import propagate_ultra
from python import Python
from memory import UnsafePointer
from collections import List

fn main() raises:
    var num_satellites = 100000
    
    var results = List[Float64]()
    results.reserve(num_satellites * 6)
    for _ in range(num_satellites * 6):
        results.append(0.0)
        
    print("Starting ULTRA-OPTIMIZED Mojo SGP4 Benchmark...")
    print("Satellites: ", num_satellites)
    
    var time_mod = Python.import_module("time")
    var start_time = time_mod.time()
    
    # Propagate
    propagate_ultra(results.unsafe_ptr(), num_satellites, 100.0)
    
    var end_time = time_mod.time()
    var duration_sec = Float64(end_time) - Float64(start_time)
    
    print("Time: ", duration_sec, " seconds")
    print("Rate: ", Float64(num_satellites) / duration_sec, " props/sec")
    
    print("First 5 results:")
    for i in range(5):
        var offset = i * 6
        print(i, results[offset], results[offset+1], results[offset+2], results[offset+3], results[offset+4], results[offset+5])
