#!/usr/bin/env python3
"""
Run all SGP4 benchmarks and display comparison results.
"""

import subprocess
import sys
import time
from pathlib import Path

def run_benchmark(name, command, cwd="."):
    """Run a benchmark and return the results."""
    print(f"\n{'='*60}")
    print(f"Running {name} Benchmark...")
    print(f"{'='*60}")
    
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode == 0:
            print(result.stdout)
            return result.stdout
        else:
            print(f"Error: {result.stderr}")
            return None
    except subprocess.TimeoutExpired:
        print(f"Timeout: {name} benchmark took too long")
        return None
    except Exception as e:
        print(f"Failed to run {name}: {e}")
        return None

def parse_rate(output, pattern):
    """Extract propagation rate from benchmark output."""
    if not output:
        return None
    
    for line in output.split('\n'):
        if 'Rate:' in line or 'props/sec' in line:
            try:
                # Extract number before 'props/sec'
                parts = line.split()
                for i, part in enumerate(parts):
                    if 'props/sec' in part or part == 'props/sec':
                        # Get the number before this
                        rate_str = parts[i-1].replace(',', '')
                        return float(rate_str)
            except (ValueError, IndexError):
                continue
    return None

def main():
    print("\n" + "="*60)
    print("SGP4 BENCHMARK COMPARISON SUITE")
    print("="*60)
    
    results = {}
    
    # Run Mojo benchmark
    mojo_output = run_benchmark(
        "Mojo",
        ["./venv/bin/mojo", "src/mojo/benchmark.mojo"]
    )
    results['Mojo'] = parse_rate(mojo_output, 'Rate:')
    
    # Run Python sgp4 benchmark
    python_output = run_benchmark(
        "Python sgp4",
        ["./venv/bin/python", "benchmarks/benchmark_python.py"]
    )
    results['Python sgp4'] = parse_rate(python_output, 'Rate:')
    
    # Run Heyoka benchmark
    heyoka_output = run_benchmark(
        "Heyoka",
        ["./venv/bin/python", "benchmarks/benchmark_heyoka.py"]
    )
    if heyoka_output and "not found" not in heyoka_output.lower():
        results['Heyoka'] = parse_rate(heyoka_output, 'Rate:')
    else:
        results['Heyoka'] = None
    
    # Display comparison table
    print("\n" + "="*60)
    print("RESULTS SUMMARY")
    print("="*60)
    print(f"\n{'Implementation':<20} {'Rate (props/sec)':<20} {'Speedup':<15}")
    print("-" * 60)
    
    baseline = results.get('Python sgp4')
    
    for name in ['Mojo', 'Python sgp4', 'Heyoka']:
        rate = results.get(name)
        if rate:
            speedup = rate / baseline if baseline else 1.0
            print(f"{name:<20} {rate:>15,.0f}      {speedup:>6.2f}x")
        else:
            print(f"{name:<20} {'N/A':<20} {'N/A':<15}")
    
    print("\n" + "="*60)
    
    # Calculate and display winner
    if results['Mojo'] and baseline:
        speedup = results['Mojo'] / baseline
        print(f"\n🚀 Mojo is {speedup:.2f}x faster than Python sgp4!")
        print(f"   Mojo: {results['Mojo']:,.0f} props/sec")
        print(f"   Python: {baseline:,.0f} props/sec")
    
    print("\n" + "="*60)
    print("\nNote: Mojo implementation uses simplified Keplerian propagation.")
    print("Full SGP4 math needs to be ported for production accuracy.")
    print("="*60 + "\n")

if __name__ == "__main__":
    main()
