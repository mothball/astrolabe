import os
import sys
import paramiko
from pathlib import Path

SERVER_IP = "173.79.187.44"
PORT = 22222
USERNAME = "sumanth"
PASSWORD = "LuckyChelli66@0@0"
REMOTE_DIR = "/home/sumanth/mojo_sgp4_benchmark"
MOJO_EXEC = "/home/sumanth/astrolabe/venv/bin/mojo"

def create_ssh_client():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        print(f"Connecting to {USERNAME}@{SERVER_IP}:{PORT}...")
        client.connect(SERVER_IP, port=PORT, username=USERNAME, password=PASSWORD)
        return client
    except Exception as e:
        print(f"Failed to connect: {e}")
        sys.exit(1)

def run_command(client, command):
    print(f"Running: {command}")
    stdin, stdout, stderr = client.exec_command(command)
    exit_status = stdout.channel.recv_exit_status()
    
    out = stdout.read().decode()
    err = stderr.read().decode()
    
    if exit_status != 0:
        print(f"Error running command: {command}")
        print(err)
        return out + "\n" + err
    
    print(out)
    return out

def main():
    print("======================================================================")
    print("DEPLOYING TWO-PHASE IMPLEMENTATION (PARAMIKO)")
    print("======================================================================")
    
    client = create_ssh_client()
    sftp = client.open_sftp()
    
    # 1. Upload files
    print("\n✓ Uploading Two-Phase files...")
    local_mojo_dir = "src/mojo"
    remote_mojo_dir = f"{REMOTE_DIR}/src/mojo"
    
    # Ensure remote directory exists
    run_command(client, f"mkdir -p {remote_mojo_dir}")
    
    files_to_upload = [
        "sgp4_two_phase.mojo",
        "benchmark_two_phase.mojo",
        "fast_math.mojo",
        "fast_math_generic.mojo",
        "fast_math_optimized.mojo",
        "verify_accuracy.mojo",
        "verify_sgp4.mojo",
        "test_prefetch.mojo",
        "sgp4_adaptive.mojo",
        "benchmark_adaptive.mojo"
    ]
    
    for file in files_to_upload:
        local_path = os.path.join(local_mojo_dir, file)
        remote_path = f"{remote_mojo_dir}/{file}"
        
        if os.path.exists(local_path):
            print(f"  {file}")
            sftp.put(local_path, remote_path)
        else:
            print(f"  Error: File not found: {local_path}")
            client.close()
            return

    # 2. Run Benchmark
    print("\n======================================================================")
    print("RUNNING TWO-PHASE BENCHMARK")
    print("======================================================================")
    
    bench_cmd = f"cd {REMOTE_DIR}/src/mojo && {MOJO_EXEC} benchmark_two_phase.mojo"
    
    print("Compiling and Running...")
    output = run_command(client, bench_cmd)

    # 2. Run Verification
    print("\n======================================================================")
    print("RUNNING SGP4 VERIFICATION")
    print("======================================================================")
    
    verify_cmd = f"cd {REMOTE_DIR}/src/mojo && {MOJO_EXEC} verify_sgp4.mojo"
    
    print("Compiling and Running...")
    
   # 3. Run Adaptive Benchmark
    print("\n======================================================================")
    print("RUNNING ADAPTIVE SGP4 BENCHMARK")
    print("======================================================================")
    
    adaptive_cmd = f"cd {REMOTE_DIR}/src/mojo && {MOJO_EXEC} benchmark_adaptive.mojo"
    output = run_command(client, adaptive_cmd)
        
    client.close()

if __name__ == "__main__":
    main()
