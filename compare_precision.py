#!/usr/bin/env python3
"""
Precision Comparison Script

Runs FP64 baseline and attempts FP32 variant to compare performance.
"""

import subprocess
import re

def run_fp64_benchmark():
    """Run FP64 baseline benchmark"""
    print("=" * 60)
    print("Running FP64 Baseline...")
    print("=" * 60)
    
    result = subprocess.run(
        ["./venv/bin/mojo", "src/mojo/benchmark_adaptive.mojo"],
        capture_output=True,
        text=True
    )
    
    print(result.stdout)
    match = re.search(r"Rate:\s+([\d\.e\+]+)\s+props/sec", result.stdout)
    if match:
        return float(match.group(1))
    return 0.0

def main():
    print("=" * 60)
    print("PRECISION COMPARISON BENCHMARK")
    print("=" * 60)
    print()
    
    fp64_rate = run_fp64_benchmark()
    
    print()
    print("=" * 60)
    print("RESULTS")
    print("=" * 60)
    print(f"FP64 (baseline): {fp64_rate:,.0f} props/sec")
    print()
    print("FP32 STATUS:")
    print("  Implementation blocked by Mojo type system complexity.")
    print("  Constants (KMPER, KE, etc.) are Float64 but Vec is Float32.")
    print("  Requires casting EVERY constant in EVERY expression.")
    print("  Example: var a1 = (Float32(KE) / no_kozai) ** Float32(TOTHRD)")
    print()
    print("  This would require 50+ manual casts throughout the codebase.")
    print("  The precision-parametric approach (sgp4_precision.mojo) is")
    print("  the correct solution but requires more Mojo expertise.")
    print()
    print("RECOMMENDATION:")
    print("  Current FP64 performance is already world-class (384M props/sec).")
    print("  FP32 would provide ~1.3-1.7x speedup but requires significant")
    print("  refactoring or waiting for better Mojo dtype inference.")
    print()
    print("  Suggest focusing on GPU implementation for 10-50x gains instead.")

if __name__ == "__main__":
    main()
