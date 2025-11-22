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
    "src/mojo/sgp4_adaptive_fp32.mojo",
    "src/mojo/benchmark_adaptive.mojo",
    "src/mojo/benchmark_adaptive_fp32.mojo",
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
        
        # Run FP64 benchmark
        print("=" * 60)
        print("Running FP64 Baseline...")
        print("=" * 60)
        cmd = f"cd {REMOTE_DIR} && /home/sumanth/astrolabe/venv/bin/mojo src/mojo/benchmark_adaptive.mojo"
        stdin, stdout, stderr = client.exec_command(cmd)
        fp64_output = stdout.read().decode('utf-8')
        print(fp64_output)
        
        # Run FP32 benchmark
        print("\n" + "=" * 60)
        print("Running FP32 Variant...")
        print("=" * 60)
        cmd = f"cd {REMOTE_DIR} && /home/sumanth/astrolabe/venv/bin/mojo src/mojo/benchmark_adaptive_fp32.mojo"
        stdin, stdout, stderr = client.exec_command(cmd)
        fp32_output = stdout.read().decode('utf-8')
        print(fp32_output)
        
        # Extract rates
        fp64_match = re.search(r"Rate:\s+([\d\.e\+]+)\s+props/sec", fp64_output)
        fp32_match = re.search(r"Rate:\s+([\d\.e\+]+)\s+props/sec", fp32_output)
        
        if fp64_match and fp32_match:
            fp64_rate = float(fp64_match.group(1))
            fp32_rate = float(fp32_match.group(1))
            speedup = fp32_rate / fp64_rate
            
            print("\n" + "=" * 60)
            print("PRECISION COMPARISON")
            print("=" * 60)
            print(f"FP64 (baseline):  {fp64_rate:>15,.0f} props/sec")
            print(f"FP32:             {fp32_rate:>15,.0f} props/sec")
            print(f"Speedup:          {speedup:>15.2f}x")
            print("=" * 60)
            
            if speedup > 1.0:
                print(f"✅ FP32 is {speedup:.2f}x faster!")
            else:
                print(f"⚠️  FP32 is {1/speedup:.2f}x slower (unexpected on AVX-512)")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        client.close()

if __name__ == "__main__":
    deploy_and_run()
