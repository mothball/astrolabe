import subprocess
import sys
import os
import re

def run_mojo_benchmark():
    print("\nRunning Mojo Benchmark...")
    mojo_path = "/home/sumanth/astrolabe/venv/bin/mojo"
    if not os.path.exists(mojo_path):
        mojo_path = "mojo" 
        
    cmd = [mojo_path, "src/mojo/benchmark_adaptive.mojo"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print(result.stdout)
        match = re.search(r"Rate:\s+([\d\.e\+]+)\s+props/sec", result.stdout)
        if match:
            return float(match.group(1))
        return 0.0
    except Exception as e:
        print(f"Mojo benchmark failed: {e}")
        return 0.0

def run_python_benchmarks():
    print("\nRunning Python Benchmarks (Heyoka + SGP4)...")
    python_path = "/home/sumanth/astrolabe/venv/bin/python"
    if not os.path.exists(python_path):
        python_path = sys.executable
        
    cmd = [python_path, "benchmark_heyoka.py"]
    heyoka_rate = 0.0
    sgp4_rate = 0.0
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print(result.stdout)
        
        # Parse Heyoka
        match_h = re.search(r"Heyoka Results:.*?Rate:\s+([\d\.e\+]+)\s+props/sec", result.stdout, re.DOTALL)
        if match_h:
            heyoka_rate = float(match_h.group(1))
            
        # Parse SGP4
        match_s = re.search(r"SGP4 Results:.*?Rate:\s+([\d\.e\+]+)\s+props/sec", result.stdout, re.DOTALL)
        if match_s:
            sgp4_rate = float(match_s.group(1))
            
    except Exception as e:
        print(f"Python benchmarks failed: {e}")
        
    return heyoka_rate, sgp4_rate

def main():
    print("Starting SGP4 Propagator Comparison")
    print("===================================")
    
    mojo_rate = run_mojo_benchmark()
    heyoka_rate, sgp4_rate = run_python_benchmarks()
    
    print("\n===================================")
    print("FINAL COMPARISON")
    print("===================================")
    
    if mojo_rate > 0:
        print(f"Mojo (Adaptive): {mojo_rate:,.0f} props/sec")
    else:
        print("Mojo: Failed")
        
    if heyoka_rate > 0:
        print(f"Heyoka:          {heyoka_rate:,.0f} props/sec")
    else:
        print("Heyoka: Failed")
        
    if sgp4_rate > 0:
        print(f"SGP4 (Python):   {sgp4_rate:,.0f} props/sec")
    else:
        print("SGP4: Failed")
        
    print("\nSpeedups (Mojo vs ...):")
    if heyoka_rate > 0:
        print(f"  vs Heyoka: {mojo_rate / heyoka_rate:.2f}x")
    if sgp4_rate > 0:
        print(f"  vs SGP4:   {mojo_rate / sgp4_rate:.2f}x")

if __name__ == "__main__":
    main()
