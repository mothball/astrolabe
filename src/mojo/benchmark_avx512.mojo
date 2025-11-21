from sgp4_avx512 import propagate_sgp4_avx512, propagate_batch_avx512, DEG2RAD
from python import Python
from collections import List
from sys import num_physical_cores

fn main() raises:
    var num_satellites = 100000
    
    print("============================================================")
    print("AVX-512 SGP4 BENCHMARK (8-wide SIMD)")
    print("============================================================")
    print("")
    print("Hardware:")
    print("  Physical cores:", num_physical_cores())
    print("  SIMD width: 8 (AVX-512)")
    print("")
    
    # Allocate arrays
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
    
    # Initialize with ISS-like orbit
    for i in range(num_satellites):
        no_kozai.append(15.54 * 2.0 * 3.141592653589793 / 1440.0)
        ecco.append(0.0001)
        inclo.append(51.6 * DEG2RAD)
        nodeo.append(0.0)
        argpo.append(0.0)
        mo.append(Float64(i) * 0.001)
        bstar.append(0.00001)
    
    var time_mod = Python.import_module("time")
    
    # Test 1: Single-time propagation
    print("Test 1: Single-Time Propagation (AVX-512)")
    print("------------------------------------------------------------")
    print("Satellites:", num_satellites)
    print("Optimizations:")
    print("  ✓ Parallel execution (32 cores)")
    print("  ✓ AVX-512 vectorization (8-wide)")
    print("  ✓ Aggressive inlining")
    print("  ✓ Heyoka-style algorithm")
    print("")
    
    var results = List[Float64]()
    results.reserve(num_satellites * 6)
    for _ in range(num_satellites * 6):
        results.append(0.0)
    
    var start = time_mod.time()
    
    propagate_sgp4_avx512(
        no_kozai.unsafe_ptr(),
        ecco.unsafe_ptr(),
        inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(),
        argpo.unsafe_ptr(),
        mo.unsafe_ptr(),
        bstar.unsafe_ptr(),
        results.unsafe_ptr(),
        num_satellites,
        100.0
    )
    
    var end = time_mod.time()
    var duration = Float64(end) - Float64(start)
    var rate = Float64(num_satellites) / duration
    
    print("Results:")
    print("  Time:", duration, "seconds")
    print("  Rate:", rate, "props/sec")
    print("")
    print("Comparison:")
    print("  vs Python sgp4 (3.2M):  ", rate / 3200000.0, "x")
    print("  vs Baseline (33.3M):    ", rate / 33300000.0, "x")
    print("  vs Heyoka 16-core (170M):", rate / 170000000.0, "x")
    print("")
    
    # Test 2: Batch-mode propagation
    print("============================================================")
    print("Test 2: Batch-Mode Propagation (AVX-512)")
    print("------------------------------------------------------------")
    print("Satellites:", num_satellites)
    print("Time steps: 10")
    print("Total propagations:", num_satellites * 10)
    print("")
    
    var num_times = 10
    var times = List[Float64]()
    for i in range(num_times):
        times.append(Float64(i) * 10.0)
    
    var batch_results = List[Float64]()
    batch_results.reserve(num_times * 6 * num_satellites)
    for _ in range(num_times * 6 * num_satellites):
        batch_results.append(0.0)
    
    start = time_mod.time()
    
    propagate_batch_avx512(
        no_kozai.unsafe_ptr(),
        ecco.unsafe_ptr(),
        inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(),
        argpo.unsafe_ptr(),
        mo.unsafe_ptr(),
        bstar.unsafe_ptr(),
        times.unsafe_ptr(),
        num_times,
        batch_results.unsafe_ptr(),
        num_satellites
    )
    
    end = time_mod.time()
    duration = Float64(end) - Float64(start)
    var total = Float64(num_satellites * num_times)
    rate = total / duration
    
    print("Results:")
    print("  Time:", duration, "seconds")
    print("  Rate:", rate, "props/sec")
    print("")
    print("Comparison:")
    print("  vs Python sgp4 (3.2M):    ", rate / 3200000.0, "x")
    print("  vs Baseline (33.3M):      ", rate / 33300000.0, "x")
    print("  vs Heyoka 16-core (170M): ", rate / 170000000.0, "x")
    print("")
    
    print("============================================================")
    print("SUMMARY")
    print("============================================================")
    print("AVX-512 optimizations:")
    print("  ✓ 8-wide Float64 SIMD (vs 4-wide)")
    print("  ✓ 32-core parallelization")
    print("  ✓ Heyoka WGS72 constants")
    print("  ✓ Batch-mode propagation")
    print("============================================================")
