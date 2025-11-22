#!/usr/bin/env python3
"""
Test different Mojo compiler optimization levels
"""

import subprocess
import re
import time

def compile_and_run(optimization="", name="Default"):
    """Compile and run benchmark with given optimization level"""
    print(f"\n{'='*60}")
    print(f"Testing: {name}")
    print(f"{'='*60}")
    
    # Compile
    compile_cmd = ["./venv/bin/mojo"]
    if optimization:
        compile_cmd.append(optimization)
    compile_cmd.append("src/mojo/benchmark_adaptive.mojo")
    
    print(f"Command: {' '.join(compile_cmd)}")
    print("Running...")
    
    try:
        result = subprocess.run(
            compile_cmd,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        print(result.stdout)
        
        # Extract rate
        match = re.search(r"Rate:\s+([\d\.e\+]+)\s+props/sec", result.stdout)
        if match:
            return float(match.group(1))
        else:
            print(f"Could not extract rate from output")
            return 0.0
            
    except subprocess.TimeoutExpired:
        print("Timeout!")
        return 0.0
    except Exception as e:
        print(f"Error: {e}")
        return 0.0

def main():
    print("=" * 60)
    print("COMPILER OPTIMIZATION COMPARISON")
    print("=" * 60)
    print()
    print("Testing different Mojo compiler optimization levels...")
    print()
    
    # Test configurations
    configs = [
        ("", "Default (no flags)"),
        ("--release", "Release mode"),
        ("-O3", "O3 optimization"),
    ]
    
    results = {}
    
    for flag, name in configs:
        rate = compile_and_run(flag, name)
        results[name] = rate
        time.sleep(1)  # Small delay between runs
    
    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    baseline_rate = results.get("Default (no flags)", 0)
    
    for name, rate in results.items():
        if rate > 0:
            speedup = rate / baseline_rate if baseline_rate > 0 else 0
            print(f"{name:30s}: {rate:>15,.0f} props/sec  ({speedup:.2f}x)")
        else:
            print(f"{name:30s}: FAILED")
    
    print("=" * 60)
    
    # Find best
    if results:
        best_name = max(results, key=results.get)
        best_rate = results[best_name]
        speedup = best_rate / baseline_rate if baseline_rate > 0 else 1.0
        
        print(f"\nBest configuration: {best_name}")
        print(f"Performance: {best_rate:,.0f} props/sec ({speedup:.2f}x vs default)")

if __name__ == "__main__":
    main()
