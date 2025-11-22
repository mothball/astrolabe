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
    "src/mojo/benchmark_adaptive.mojo",
    "src/mojo/benchmark_adaptive_halley.mojo",
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
        
        # Run Newton-Raphson benchmark
        print("=" * 60)
        print("Running Newton-Raphson (3 iterations)...")
        print("=" * 60)
        cmd = f"cd {REMOTE_DIR} && /home/sumanth/astrolabe/venv/bin/mojo src/mojo/benchmark_adaptive.mojo"
        stdin, stdout, stderr = client.exec_command(cmd)
        newton_output = stdout.read().decode('utf-8')
        print(newton_output)
        
        # Run Halley's method benchmark
        print("\n" + "=" * 60)
        print("Running Halley's Method (2 iterations)...")
        print("=" * 60)
        cmd = f"cd {REMOTE_DIR} && /home/sumanth/astrolabe/venv/bin/mojo src/mojo/benchmark_adaptive_halley.mojo"
        stdin, stdout, stderr = client.exec_command(cmd)
        halley_output = stdout.read().decode('utf-8')
        print(halley_output)
        
        # Extract rates
        newton_match = re.search(r"Rate:\s+([\d\.e\+]+)\s+props/sec", newton_output)
        halley_match = re.search(r"Rate:\s+([\d\.e\+]+)\s+props/sec", halley_output)
        
        if newton_match and halley_match:
            newton_rate = float(newton_match.group(1))
            halley_rate = float(halley_match.group(1))
            speedup = halley_rate / newton_rate
            
            print("\n" + "=" * 60)
            print("KEPLER SOLVER COMPARISON")
            print("=" * 60)
            print(f"Newton-Raphson (3 iter):  {newton_rate:>15,.0f} props/sec")
            print(f"Halley's Method (2 iter): {halley_rate:>15,.0f} props/sec")
            print(f"Speedup:                  {speedup:>15.2f}x")
            print("=" * 60)
            
            if speedup > 1.05:
                print(f"✅ Halley's method is {speedup:.2f}x faster!")
            elif speedup > 0.95:
                print(f"⚖️  Performance is roughly equal (within 5%)")
            else:
                print(f"⚠️  Halley's method is {1/speedup:.2f}x slower")
                
            print("\nAnalysis:")
            print("  - Halley's method uses 2 iterations vs 3 for Newton-Raphson")
            print("  - But each iteration requires computing f''(E) = e*sin(E)")
            print("  - sin/cos are already computed for f and f'")
            print("  - Trade-off: fewer iterations vs more operations per iteration")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        client.close()

if __name__ == "__main__":
    deploy_and_run()
