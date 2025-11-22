import subprocess
import sys
import os
import re
import paramiko

SERVER_IP = "173.79.187.44"
USERNAME = "sumanth"
PORT = 22222
PASSWORD = "LuckyChelli66@0@0"
REMOTE_DIR = "/home/sumanth/mojo_sgp4_benchmark"

FILES_TO_UPLOAD = [
    "src/mojo/sgp4_adaptive.mojo",
    "src/mojo/sgp4_adaptive_halley.mojo",
    "src/mojo/sgp4_adaptive_micro.mojo",
    "src/mojo/benchmark_adaptive.mojo",
    "src/mojo/benchmark_adaptive_halley.mojo",
    "src/mojo/benchmark_adaptive_micro.mojo",
    "src/mojo/fast_math_optimized.mojo"
]

def deploy_and_run():
    print(f"Connecting to {SERVER_IP}:{PORT}...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(SERVER_IP, port=PORT, username=USERNAME, password=PASSWORD)
        print("Connected successfully.")
        
        sftp = client.open_sftp()
        
        # Create directories
        try:
            sftp.mkdir(f"{REMOTE_DIR}/src")
        except IOError: pass
        try:
            sftp.mkdir(f"{REMOTE_DIR}/src/mojo")
        except IOError: pass

        # Upload files
        print("Uploading files...")
        for local_file in FILES_TO_UPLOAD:
            remote_file = f"{REMOTE_DIR}/{local_file}"
            if os.path.exists(local_file):
                print(f"  {local_file}")
                sftp.put(local_file, remote_file)
        
        sftp.close()
        print("Upload complete.\n")
        
        results = {}
        
        # Run baseline
        print("=" * 60)
        print("1. Baseline (Newton, no extra opts)")
        print("=" * 60)
        cmd = f"cd {REMOTE_DIR} && /home/sumanth/astrolabe/venv/bin/mojo src/mojo/benchmark_adaptive.mojo"
        stdin, stdout, stderr = client.exec_command(cmd)
        output = stdout.read().decode('utf-8')
        print(output)
        match = re.search(r"Rate:\s+([\d\.e\+]+)\s+props/sec", output)
        if match:
            results["Baseline"] = float(match.group(1))
        
        # Run Halley
        print("\n" + "=" * 60)
        print("2. Halley's Method")
        print("=" * 60)
        cmd = f"cd {REMOTE_DIR} && /home/sumanth/astrolabe/venv/bin/mojo src/mojo/benchmark_adaptive_halley.mojo"
        stdin, stdout, stderr = client.exec_command(cmd)
        output = stdout.read().decode('utf-8')
        print(output)
        match = re.search(r"Rate:\s+([\d\.e\+]+)\s+props/sec", output)
        if match:
            results["Halley"] = float(match.group(1))
        
        # Run micro-optimized
        print("\n" + "=" * 60)
        print("3. Micro-Optimized (Unrolled + Heavy Inlining)")
        print("=" * 60)
        cmd = f"cd {REMOTE_DIR} && /home/sumanth/astrolabe/venv/bin/mojo src/mojo/benchmark_adaptive_micro.mojo"
        stdin, stdout, stderr = client.exec_command(cmd)
        output = stdout.read().decode('utf-8')
        print(output)
        match = re.search(r"Rate:\s+([\d\.e\+]+)\s+props/sec", output)
        if match:
            results["Micro-Opt"] = float(match.group(1))
        
        # Summary
        print("\n" + "=" * 60)
        print("MICRO-OPTIMIZATION RESULTS")
        print("=" * 60)
        
        baseline = results.get("Baseline", 0)
        
        for name, rate in results.items():
            speedup = rate / baseline if baseline > 0 else 0
            print(f"{name:20s}: {rate:>15,.0f} props/sec  ({speedup:.3f}x)")
        
        print("=" * 60)
        
        print("\nOptimizations applied in Micro-Opt:")
        print("  1. ✅ Manual loop unrolling (Kepler solver)")
        print("  2. ✅ @always_inline with @parameter forcing")
        print("  3. ✅ All branches already branchless (select_simd)")
        
        if "Micro-Opt" in results and baseline > 0:
            speedup = results["Micro-Opt"] / baseline
            if speedup > 1.05:
                print(f"\n✅ Micro-opts provide {speedup:.1%} speedup!")
            elif speedup > 0.95:
                print(f"\n⚖️  Micro-opts neutral (within 5%)")
            else:
                print(f"\n❌ Micro-opts slower ({1/speedup:.1%} regression)")
                print("   → Compiler already optimizing well")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        client.close()

if __name__ == "__main__":
    deploy_and_run()
