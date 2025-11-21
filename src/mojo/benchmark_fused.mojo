from sgp4_fused import propagate_fused, propagate_fused_batch, DEG2RAD
from python import Python
from collections import List

fn main() raises:
    var num_satellites = 100000
    
    print("=" * 60)
    print("EXPRESSION FUSION - Heyoka-Style Mega-Expression")
    print("=" * 60)
    
    # Allocate arrays
    var no_kozai = List[Float64]()
    var ecco = List[Float64]()
    var inclo = List[Float64]()
    var nodeo = List[Float64]()
    var argpo = List[Float64]()
    var mo = List[Float64]()
    var bstar = List[Float64]()
    var results = List[Float64]()
    
    no_kozai.reserve(num_satellites)
    ecco.reserve(num_satellites)
    inclo.reserve(num_satellites)
    nodeo.reserve(num_satellites)
    argpo.reserve(num_satellites)
    mo.reserve(num_satellites)
    bstar.reserve(num_satellites)
    results.reserve(num_satellites * 6)
    
    # Initialize
    for i in range(num_satellites):
        no_kozai.append(15.54 * 2.0 * 3.141592653589793 / 1440.0)
        ecco.append(0.0001)
        inclo.append(51.6 * DEG2RAD)
        nodeo.append(0.0)
        argpo.append(0.0)
        mo.append(Float64(i) * 0.001)
        bstar.append(0.00001)
    
    for _ in range(num_satellites * 6):
        results.append(0.0)
    
    var time_mod = Python.import_module("time")
    
    # Test 1: Single-time with fusion
    print("\nTest 1: Single-Time (Fused Expressions)")
    print("-" * 60)
    print("Satellites:", num_satellites)
    print("Technique: Mega-expression fusion")
    
    var start_time = time_mod.time()
    
    propagate_fused(
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
    
    var end_time = time_mod.time()
    var duration_sec = Float64(end_time) - Float64(start_time)
    var rate = Float64(num_satellites) / duration_sec
    
    print("\nResults:")
    print("  Time:", duration_sec, "seconds")
    print("  Rate:", rate, "props/sec")
    print("\nComparison:")
    print("  vs Python sgp4 (3.2M):  ", rate / 3200000.0, "x")
    print("  vs Previous best (19.9M):", rate / 19900000.0, "x")
    print("  vs Heyoka single (13M):  ", rate / 13000000.0, "x")
    
    # Test 2: Batch-mode with fusion
    print("\n" + "=" * 60)
    print("Test 2: Batch-Mode (Fused Expressions)")
    print("-" * 60)
    
    var num_times = 10
    var times = List[Float64]()
    for i in range(num_times):
        times.append(Float64(i) * 10.0)
    
    var batch_results = List[Float64]()
    batch_results.reserve(num_times * 6 * num_satellites)
    for _ in range(num_times * 6 * num_satellites):
        batch_results.append(0.0)
    
    print("Satellites:", num_satellites)
    print("Time steps:", num_times)
    print("Total propagations:", num_satellites * num_times)
    
    start_time = time_mod.time()
    
    propagate_fused_batch(
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
    
    end_time = time_mod.time()
    duration_sec = Float64(end_time) - Float64(start_time)
    var total_props = Float64(num_satellites * num_times)
    rate = total_props / duration_sec
    
    print("\nResults:")
    print("  Time:", duration_sec, "seconds")
    print("  Rate:", rate, "props/sec")
    print("\nComparison:")
    print("  vs Python sgp4 (3.2M):   ", rate / 3200000.0, "x")
    print("  vs Previous best (19.9M):", rate / 19900000.0, "x")
    print("  vs Heyoka 16-core (170M):", rate / 170000000.0, "x")
    
    print("\n" + "=" * 60)
    print("Expression Fusion Impact:")
    print("  - All operations fused at compile time")
    print("  - LLVM optimizes entire expression tree")
    print("  - Minimal function call overhead")
    print("=" * 60)
