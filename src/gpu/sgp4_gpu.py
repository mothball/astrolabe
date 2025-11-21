#!/usr/bin/env python3
"""
GPU-Accelerated SGP4 using CUDA
Optimized for NVIDIA RTX 5060Ti
Target: 10-20 billion propagations/second
"""

import cupy as cp
import numpy as np
import time
from pathlib import Path

# Compile CUDA kernel
kernel_source = Path(__file__).parent / "sgp4_kernel.cu"
sgp4_module = cp.RawModule(code=kernel_source.read_text(), options=('-std=c++14',))
sgp4_kernel = sgp4_module.get_function('sgp4_propagate_batch_kernel')

DEG2RAD = 0.017453292519943295

class SGP4_GPU:
    """GPU-Accelerated SGP4 Propagator"""
    
    def __init__(self):
        """Initialize GPU propagator"""
        self.device_info()
    
    def device_info(self):
        """Print GPU information"""
        print("=" * 70)
        print("GPU DEVICE INFORMATION")
        print("=" * 70)
        device = cp.cuda.Device(0)
        print(f"Device Name: {device.name}")
        print(f"Compute Capability: {device.compute_capability}")
        print(f"Total Memory: {device.mem_info[1] / 1024**3:.2f} GB")
        print(f"Multiprocessors: {device.attributes['MultiProcessorCount']}")
        print(f"CUDA Cores (est): {device.attributes['MultiProcessorCount'] * 128}")
        print("=" * 70)
        print()
    
    def propagate_batch(self, no_kozai, ecco, inclo, nodeo, argpo, mo, bstar, times):
        """
        Propagate batch of satellites on GPU
        
        Args:
            no_kozai: Mean motion (rad/min) - array of shape (n_satellites,)
            ecco: Eccentricity - array of shape (n_satellites,)
            inclo: Inclination (rad) - array of shape (n_satellites,)
            nodeo: Right ascension (rad) - array of shape (n_satellites,)
            argpo: Argument of perigee (rad) - array of shape (n_satellites,)
            mo: Mean anomaly (rad) - array of shape (n_satellites,)
            bstar: Drag coefficient - array of shape (n_satellites,)
            times: Time steps (min) - array of shape (n_times,)
        
        Returns:
            results: Position/velocity - shape (n_times, n_satellites, 6)
        """
        num_satellites = len(no_kozai)
        num_times = len(times)
        
        # Transfer to GPU
        d_no_kozai = cp.asarray(no_kozai, dtype=cp.float64)
        d_ecco = cp.asarray(ecco, dtype=cp.float64)
        d_inclo = cp.asarray(inclo, dtype=cp.float64)
        d_nodeo = cp.asarray(nodeo, dtype=cp.float64)
        d_argpo = cp.asarray(argpo, dtype=cp.float64)
        d_mo = cp.asarray(mo, dtype=cp.float64)
        d_bstar = cp.asarray(bstar, dtype=cp.float64)
        d_times = cp.asarray(times, dtype=cp.float64)
        
        # Allocate output
        d_results = cp.zeros(num_satellites * num_times * 6, dtype=cp.float64)
        
        # Launch configuration
        threads_per_block = 256
        blocks_x = (num_satellites + threads_per_block - 1) // threads_per_block
        
        # Launch kernel
        sgp4_kernel(
            (blocks_x, num_times), (threads_per_block,),
            (d_no_kozai, d_ecco, d_inclo, d_nodeo, d_argpo, d_mo, d_bstar,
             d_times, num_times, d_results, num_satellites)
        )
        
        cp.cuda.Stream.null.synchronize()
        
        # Reshape and transfer back
        results = cp.asnumpy(d_results).reshape(6, num_times, num_satellites)
        # Transpose to (n_times, n_satellites, 6)
        results = np.transpose(results, (1, 2, 0))
        
        return results


def benchmark_gpu(num_satellites=100000, num_times=10):
    """Benchmark GPU performance"""
    print("=" * 70)
    print("GPU SGP4 BENCHMARK")
    print("=" * 70)
    print(f"Satellites: {num_satellites:,}")
    print(f"Time steps: {num_times}")
    print(f"Total propagations: {num_satellites * num_times:,}")
    print()
    
    # Initialize propagator
    sgp4_gpu = SGP4_GPU()
    
    # Generate test data
    print("Generating test data...")
    no_kozai = np.full(num_satellites, 0.05, dtype=np.float64)
    ecco = np.full(num_satellites, 0.001, dtype=np.float64)
    inclo = np.full(num_satellites, 51.6 * DEG2RAD, dtype=np.float64)
    nodeo = np.linspace(0, 2*np.pi, num_satellites, dtype=np.float64)
    argpo = np.linspace(0, 2*np.pi, num_satellites, dtype=np.float64)
    mo = np.linspace(0, 2*np.pi, num_satellites, dtype=np.float64)
    bstar = np.full(num_satellites, 0.0001, dtype=np.float64)
    times = np.arange(num_times, dtype=np.float64) * 60.0
    
    # Warmup
    print("Warming up GPU...")
    _ = sgp4_gpu.propagate_batch(
        no_kozai[:1000], ecco[:1000], inclo[:1000], nodeo[:1000],
        argpo[:1000], mo[:1000], bstar[:1000], times
    )
    
    # Benchmark
    print("Running benchmark...")
    print()
    
    start = time.time()
    results = sgp4_gpu.propagate_batch(
        no_kozai, ecco, inclo, nodeo, argpo, mo, bstar, times
    )
    end = time.time()
    
    duration = end - start
    props_per_sec = (num_satellites * num_times) / duration
    
    print("=" * 70)
    print("RESULTS")
    print("=" * 70)
    print(f"Time: {duration:.4f} seconds")
    print(f"Throughput: {props_per_sec:,.0f} props/sec")
    print(f"           {props_per_sec/1e9:.2f} billion props/sec")
    print()
    
    # Sample output
    print("Sample output (first satellite, first time):")
    print(f"  Position: [{results[0,0,0]:.3f}, {results[0,0,1]:.3f}, {results[0,0,2]:.3f}] km")
    print(f"  Velocity: [{results[0,0,3]:.6f}, {results[0,0, 4]:.6f}, {results[0,0,5]:.6f}] km/s")
    print("=" * 70)
    
    return props_per_sec


if __name__ == "__main__":
    # Run benchmark
    throughput = benchmark_gpu(num_satellites=1000000, num_times=10)
    
    print()
    print("COMPARISON TO CPU:")
    print(f"  CPU Peak: 420,000,000 props/sec")
    print(f"  GPU Peak: {throughput:,.0f} props/sec")
    print(f"  Speedup: {throughput / 420_000_000:.1f}x faster")
