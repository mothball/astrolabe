from sgp4_adaptive_halley import propagate_batch_adaptive, DEG2RAD, SIMD_WIDTH
from python import Python
from collections import List

fn main() raises:
    print("============================================================")
    print("ADAPTIVE SGP4 BENCHMARK (Halley's Method)")
    print("============================================================")
    print("Detected SIMD Width: " + String(SIMD_WIDTH) + " x Float64")
    
    @parameter
    if SIMD_WIDTH == 8:
        print("Architecture: AVX-512 (or equivalent)")
    elif SIMD_WIDTH == 4:
        print("Architecture: AVX2 or NEON (128-bit)")
    elif SIMD_WIDTH == 2:
        print("Architecture: SSE2 (legacy)")
    else:
        print("Architecture: SIMD width = " + String(SIMD_WIDTH))
    
    var num_satellites = 100000
    var num_times = 10
    
    var no_kozai = List[Float64]()
    var ecco = List[Float64]()
    var inclo = List[Float64]()
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
    
    print("\nTest: Batch-Mode Propagation (Adaptive)")
    print("------------------------------------------------------------")
    print("Satellites: " + String(num_satellites))
    print("Time steps: " + String(num_times))
    print("Total propagations: " + String(num_satellites * num_times))
    
    var time_mod = Python.import_module("time")
    var start_time = time_mod.time()
    
    propagate_batch_adaptive(
        no_kozai.unsafe_ptr(),
        ecco.unsafe_ptr(),
        inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(),
        argpo.unsafe_ptr(),
        mo.unsafe_ptr(),
        bstar.unsafe_ptr(),
        times.unsafe_ptr(),
        num_times,
        results.unsafe_ptr(),
        num_satellites
    )
    
    var end_time = time_mod.time()
    var duration = Float64(end_time) - Float64(start_time)
    var props_per_sec = Float64(num_satellites * num_times) / duration
    
    print("\nResults:")
    print("  Time: " + String(duration) + " seconds")
    print("  Rate: " + String(props_per_sec) + " props/sec")
    print("\n✓ Benchmark complete!")
