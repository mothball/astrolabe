from sgp4_simd import SatelliteData, propagate_simd
from python import Python

fn main() raises:
    var num_satellites = 100000
    
    print("Starting SIMD-OPTIMIZED Mojo SGP4 Benchmark...")
    print("Satellites: ", num_satellites)
    
    # Allocate data in SoA format
    var data = SatelliteData(num_satellites)
    
    var time_mod = Python.import_module("time")
    var start_time = time_mod.time()
    
    # Propagate with SIMD
    propagate_simd(data)
    
    var end_time = time_mod.time()
    var duration_sec = Float64(end_time) - Float64(start_time)
    
    print("Time: ", duration_sec, " seconds")
    print("Rate: ", Float64(num_satellites) / duration_sec, " props/sec")
    
    print("First 5 results:")
    for i in range(5):
        print(i, data.result_x[i], data.result_y[i], data.result_z[i], 
              data.result_vx[i], data.result_vy[i], data.result_vz[i])
    
    # Cleanup
    data.free()
