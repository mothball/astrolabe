from sgp4_real import propagate_sgp4_real, DEG2RAD
from python import Python
from memory import UnsafePointer
from collections import List

fn main() raises:
    var num_satellites = 100000
    
    # Allocate arrays for orbital elements (Structure of Arrays)
    var no_kozai = List[Float64]()
    var ecco = List[Float64]()
    var inclo = List[Float64]()
    var nodeo = List[Float64]()
    var argpo = List[Float64]()
    var mo = List[Float64]()
    var bstar = List[Float64]()
    var results = List[Float64]()
    
    # Reserve memory
    no_kozai.reserve(num_satellites)
    ecco.reserve(num_satellites)
    inclo.reserve(num_satellites)
    nodeo.reserve(num_satellites)
    argpo.reserve(num_satellites)
    mo.reserve(num_satellites)
    bstar.reserve(num_satellites)
    results.reserve(num_satellites * 6)
    
    # Initialize with realistic ISS-like orbital elements
    for i in range(num_satellites):
        no_kozai.append(15.54 * 2.0 * 3.141592653589793 / 1440.0)  # ~15.54 revs/day in rad/min
        ecco.append(0.0001)  # Low eccentricity
        inclo.append(51.6 * DEG2RAD)  # ISS inclination
        nodeo.append(0.0)  # RAAN
        argpo.append(0.0)  # Argument of perigee
        mo.append(Float64(i) * 0.001)  # Varying mean anomaly
        bstar.append(0.00001)  # Drag term
    
    # Initialize results
    for _ in range(num_satellites * 6):
        results.append(0.0)
        
    print("Starting REAL SGP4 Mojo Benchmark...")
    print("Satellites: ", num_satellites)
    
    var time_mod = Python.import_module("time")
    var start_time = time_mod.time()
    
    # Propagate with real SGP4
    propagate_sgp4_real(
        no_kozai.unsafe_ptr(),
        ecco.unsafe_ptr(),
        inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(),
        argpo.unsafe_ptr(),
        mo.unsafe_ptr(),
        bstar.unsafe_ptr(),
        results.unsafe_ptr(),
        num_satellites,
        100.0  # 100 minutes since epoch
    )
    
    var end_time = time_mod.time()
    var duration_sec = Float64(end_time) - Float64(start_time)
    
    print("Time: ", duration_sec, " seconds")
    print("Rate: ", Float64(num_satellites) / duration_sec, " props/sec")
    
    print("\nFirst 5 results (position in km, velocity in km/s):")
    for i in range(5):
        var offset = i * 6
        print(i, "pos:", results[offset], results[offset+1], results[offset+2])
        print("  vel:", results[offset+3], results[offset+4], results[offset+5])
