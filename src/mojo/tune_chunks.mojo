from sgp4_adaptive import propagate_batch_adaptive, DEG2RAD, SIMD_WIDTH
from python import Python
from collections import List

fn test_chunk_size(chunk_size: Int) raises -> Float64:
    var num_satellites = 100000
    var num_times = 10
    
    var no_kozai = List[Float64]()
    var ecco = List[Float64]()
    var inclo =List[Float64]()
    var nodeo = List[Float64]()
    var argpo = List[Float64]()
    var mo = List[Float64]()
    var bstar = List[Float64]()
    
    no_kozai.reserve(num_satellites)
    ecco.reserve(num_satellites)
    inclo.reserve(num_satellites)
    nodeo.reserve(num_satellites)
    argpo.reserve(num_satellites)
    mo.reserve(num_satellites)
    bstar.reserve(num_satellites)
    
    for i in range(num_satellites):
        no_kozai.append(0.05 + Float64(i % 100) * 0.0001)
        ecco.append(0.001)
        inclo.append(51.6 * DEG2RAD)
        nodeo.append(Float64(i) * 0.01)
        argpo.append(Float64(i) * 0.01)
        mo.append(Float64(i) * 0.01)
        bstar.append(0.0001)
        
    var times = List[Float64]()
    times.reserve(num_times)
    for i in range(num_times):
        times.append(Float64(i) * 60.0)
        
    var results = List[Float64]()
    results.reserve(num_satellites * num_times * 6)
    for _ in range(num_satellites * num_times * 6):
        results.append(0.0)
    
    var time_mod = Python.import_module("time")
    
    # Warmup
    propagate_batch_adaptive(
        no_kozai.unsafe_ptr(), ecco.unsafe_ptr(), inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(), argpo.unsafe_ptr(), mo.unsafe_ptr(),
        bstar.unsafe_ptr(), times.unsafe_ptr(), num_times,
        results.unsafe_ptr(), num_satellites
    )
    
    # Actual timing
    var start_time = time_mod.time()
    propagate_batch_adaptive(
        no_kozai.unsafe_ptr(), ecco.unsafe_ptr(), inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(), argpo.unsafe_ptr(), mo.unsafe_ptr(),
        bstar.unsafe_ptr(), times.unsafe_ptr(), num_times,
        results.unsafe_ptr(), num_satellites
    )
    var end_time = time_mod.time()
    
    var duration = Float64(end_time) - Float64(start_time)
    return Float64(num_satellites * num_times) / duration

fn main() raises:
    print("============================================================")
    print("CHUNK SIZE TUNING")
    print("============================================================")
    print("SIMD Width: " + String(SIMD_WIDTH))
    print()
    
    var chunk_sizes = List[Int]()
    chunk_sizes.append(1024)
    chunk_sizes.append(2048)
    chunk_sizes.append(4096)
    chunk_sizes.append(8192)
    chunk_sizes.append(16384)
    
    var best_size = 4096
    var best_rate = 0.0
    
    for i in range(len(chunk_sizes)):
        var chunk = chunk_sizes[i]
        print("Testing chunk size: " + String(chunk))
        
        # Run 3 times and take best
        var best_run = 0.0
        for _ in range(3):
            var rate = test_chunk_size(chunk)
            if rate > best_run:
                best_run = rate
        
        print("  Rate: " + String(best_run) + " props/sec")
        print()
        
        if best_run > best_rate:
            best_rate = best_run
            best_size = chunk
    
    print("============================================================")
    print("OPTIMAL CHUNK SIZE: " + String(best_size))
    print("BEST PERFORMANCE: " + String(best_rate) + " props/sec")
    print("============================================================")
