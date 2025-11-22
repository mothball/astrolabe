from sgp4_precision import propagate_batch, PRECISION_FP64, PRECISION_FP32, KEPLER_NEWTON, KEPLER_HALLEY, KEPLER_ADAPTIVE
from python import Python, PythonObject
from collections import List
from builtin.dtype import DType

alias DEG2RAD: Float64 = 0.017453292519943295

fn run_benchmark[T: DType, S: Int, KEPLER_MODE: Int](
    variant_name: String,
    no_kozai: UnsafePointer[Float64],
    ecco: UnsafePointer[Float64],
    inclo: UnsafePointer[Float64],
    nodeo: UnsafePointer[Float64],
    argpo: UnsafePointer[Float64],
    mo: UnsafePointer[Float64],
    bstar: UnsafePointer[Float64],
    times: UnsafePointer[Float64],
    num_times: Int,
    results: UnsafePointer[Float64],
    num_satellites: Int,
    time_mod: PythonObject
) raises -> Float64:
    print("Testing: " + variant_name)
    
    var start_time = time_mod.time()
    propagate_batch[T, S, KEPLER_MODE](
        no_kozai, ecco, inclo, nodeo, argpo, mo, bstar,
        times, num_times, results, num_satellites
    )
    var end_time = time_mod.time()
    
    var duration = Float64(end_time) - Float64(start_time)
    var props_per_sec = Float64(num_satellites * num_times) / duration
    
    print("  Time: " + String(duration) + " seconds")
    print("  Rate: " + String(props_per_sec) + " props/sec")
    
    return props_per_sec

fn main() raises:
    print("=" * 60)
    print("TIER 2 OPTIMIZATION BENCHMARK SUITE")
    print("=" * 60)
    print("")
    
    var num_satellites = 10000
    var num_times = 10
    alias SIMD_WIDTH = 8
    
    print("Configuration:")
    print("  Satellites: " + String(num_satellites))
    print("  Time steps: " + String(num_times))
    print("  Total propagations: " + String(num_satellites * num_times))
    print("  SIMD Width: " + String(SIMD_WIDTH))
    print("")
    
    # Allocate input data
    var no_kozai = List[Float64]()
    var ecco = List[Float64]()
    var inclo = List[Float64]()
    var nodeo = List[Float64]()
    var argpo = List[Float64]()
    var mo = List[Float64]()
    var bstar = List[Float64]()
    var times = List[Float64]()
    
    no_kozai.reserve(num_satellites)
    ecco.reserve(num_satellites)
    inclo.reserve(num_satellites)
    nodeo.reserve(num_satellites)
    argpo.reserve(num_satellites)
    mo.reserve(num_satellites)
    bstar.reserve(num_satellites)
    times.reserve(num_times)
    
    # Initialize data (ISS-like orbit)
    for i in range(num_satellites):
        no_kozai.append(0.05 + Float64(i % 100) * 0.0001)
        ecco.append(0.001)
        inclo.append(51.6 * DEG2RAD)
        nodeo.append(Float64(i) * 0.01)
        argpo.append(Float64(i) * 0.01)
        mo.append(Float64(i) * 0.01)
        bstar.append(0.0001)
    
    for i in range(num_times):
        times.append(Float64(i) * 60.0)
    
    # Allocate results
    var results = List[Float64]()
    results.reserve(num_satellites * num_times * 6)
    for _ in range(num_satellites * num_times * 6):
        results.append(0.0)
    
    var time_mod = Python.import_module("time")
    
    print("=" * 60)
    print("BENCHMARK RESULTS")
    print("=" * 60)
    print("")
    
    # Run benchmarks
    var rates = List[Float64]()
    rates.reserve(7)
    
    # 1. Baseline: FP64 + Newton (3 iterations)
    rates.append(run_benchmark[DType.float64, SIMD_WIDTH, KEPLER_NEWTON](
        "FP64 + Newton (3-iter) [BASELINE]",
        no_kozai.unsafe_ptr(), ecco.unsafe_ptr(), inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(), argpo.unsafe_ptr(), mo.unsafe_ptr(), bstar.unsafe_ptr(),
        times.unsafe_ptr(), num_times, results.unsafe_ptr(), num_satellites, time_mod
    ))
    print("")
    
    # 2. FP32 + Newton
    rates.append(run_benchmark[DType.float32, SIMD_WIDTH, KEPLER_NEWTON](
        "FP32 + Newton (3-iter)",
        no_kozai.unsafe_ptr(), ecco.unsafe_ptr(), inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(), argpo.unsafe_ptr(), mo.unsafe_ptr(), bstar.unsafe_ptr(),
        times.unsafe_ptr(), num_times, results.unsafe_ptr(), num_satellites, time_mod
    ))
    print("")
    
    # 3. FP64 + Halley (2 iterations)
    rates.append(run_benchmark[DType.float64, SIMD_WIDTH, KEPLER_HALLEY](
        "FP64 + Halley (2-iter)",
        no_kozai.unsafe_ptr(), ecco.unsafe_ptr(), inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(), argpo.unsafe_ptr(), mo.unsafe_ptr(), bstar.unsafe_ptr(),
        times.unsafe_ptr(), num_times, results.unsafe_ptr(), num_satellites, time_mod
    ))
    print("")
    
    # 4. FP32 + Halley
    rates.append(run_benchmark[DType.float32, SIMD_WIDTH, KEPLER_HALLEY](
        "FP32 + Halley (2-iter)",
        no_kozai.unsafe_ptr(), ecco.unsafe_ptr(), inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(), argpo.unsafe_ptr(), mo.unsafe_ptr(), bstar.unsafe_ptr(),
        times.unsafe_ptr(), num_times, results.unsafe_ptr(), num_satellites, time_mod
    ))
    print("")
    
    # 5. FP64 + Adaptive iterations
    rates.append(run_benchmark[DType.float64, SIMD_WIDTH, KEPLER_ADAPTIVE](
        "FP64 + Adaptive Iterations",
        no_kozai.unsafe_ptr(), ecco.unsafe_ptr(), inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(), argpo.unsafe_ptr(), mo.unsafe_ptr(), bstar.unsafe_ptr(),
        times.unsafe_ptr(), num_times, results.unsafe_ptr(), num_satellites, time_mod
    ))
    print("")
    
    # 6. FP32 + Adaptive
    rates.append(run_benchmark[DType.float32, SIMD_WIDTH, KEPLER_ADAPTIVE](
        "FP32 + Adaptive Iterations",
        no_kozai.unsafe_ptr(), ecco.unsafe_ptr(), inclo.unsafe_ptr(),
        nodeo.unsafe_ptr(), argpo.unsafe_ptr(), mo.unsafe_ptr(), bstar.unsafe_ptr(),
        times.unsafe_ptr(), num_times, results.unsafe_ptr(), num_satellites, time_mod
    ))
    print("")
    
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print("")
    
    var baseline = rates[0]
    print("Variant                          | Props/sec       | Speedup")
    print("-" * 60)
    print("FP64 + Newton (BASELINE)         | " + String(Int(rates[0])) + " | 1.00x")
    print("FP32 + Newton                    | " + String(Int(rates[1])) + " | " + String(rates[1]/baseline) + "x")
    print("FP64 + Halley                    | " + String(Int(rates[2])) + " | " + String(rates[2]/baseline) + "x")
    print("FP32 + Halley                    | " + String(Int(rates[3])) + " | " + String(rates[3]/baseline) + "x")
    print("FP64 + Adaptive                  | " + String(Int(rates[4])) + " | " + String(rates[4]/baseline) + "x")
    print("FP32 + Adaptive                  | " + String(Int(rates[5])) + " | " + String(rates[5]/baseline) + "x")
    print("")
    print("=" * 60)
