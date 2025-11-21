from sgp4_two_phase import propagate_batch_two_phase, DEG2RAD
from python import Python
from collections import List
from sys import num_physical_cores

fn main() raises:
    print("============================================================")
    print("TWO-PHASE SGP4 BENCHMARK (AVX-512)")
    print("============================================================")
    
    var num_satellites = 100000
    var num_times = 10
    
    # Allocate arrays using List
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
    
    # Initialize with random-ish data
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
        
    # Output buffer
    var results = List[Float64]()
    results.reserve(num_satellites * num_times * 6)
    for _ in range(num_satellites * num_times * 6):
        results.append(0.0)
    
    print("\nTest: Batch-Mode Propagation (Two-Phase)")
    print("------------------------------------------------------------")
    print("Satellites: " + String(num_satellites))
    print("Time steps: " + String(num_times))
    print("Total propagations: " + String(num_satellites * num_times))
    
    var time_mod = Python.import_module("time")
    var start_time = time_mod.time()
    
    propagate_batch_two_phase(
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
