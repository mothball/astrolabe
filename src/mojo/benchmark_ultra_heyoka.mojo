from sgp4_ultra_heyoka import propagate_sgp4_ultra, DEG2RAD
from python import Python
from collections import List

fn main() raises:
    var num_satellites = 100000
    
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
        
    print("HEYOKA-STYLE ULTRA-OPTIMIZED Mojo SGP4")
    print("=" * 50)
    print("Satellites: ", num_satellites)
    print("SIMD Width: 8 (AVX-512 ready)")
    print("Optimizations:")
    print("  - 8-wide SIMD")
    print("  - Aggressive inlining")
    print("  - Unrolled Kepler solver")
    print("  - True SoA layout")
    print("=" * 50)
    
    var time_mod = Python.import_module("time")
    var start_time = time_mod.time()
    
    # Propagate
    propagate_sgp4_ultra(
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
    
    print("\nRESULTS:")
    print("Time: ", duration_sec, " seconds")
    print("Rate: ", Float64(num_satellites) / duration_sec, " props/sec")
    print("\nCOMPARISON:")
    print("  vs Python sgp4 (3.2M):  ", Float64(num_satellites) / duration_sec / 3200000.0, "x")
    print("  vs Mojo SIMD-4 (11.6M): ", Float64(num_satellites) / duration_sec / 11600000.0, "x")
    print("  vs Heyoka single (13M): ", Float64(num_satellites) / duration_sec / 13000000.0, "x")
    
    print("\nFirst 3 results:")
    for i in range(3):
        var offset = i * 6
        print(i, "pos:", results[offset], results[offset+1], results[offset+2])
