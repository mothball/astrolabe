#!/usr/bin/env python3
"""Deploy and test Mojo native GPU implementation"""

import paramiko
import os
from pathlib import Path

SERVER_IP = "173.79.187.44"
USERNAME = "sumanth"
PORT = 22222
PASSWORD = "LuckyChelli66@0@0"
REMOTE_DIR = "/home/sumanth/mojo_sgp4_benchmark"
VENV_MOJO = f"{REMOTE_DIR}/../astrolabe/venv/bin/mojo"

def run_command(client, command):
    print(f"Running: {command}")
    stdin, stdout, stderr = client.exec_command(command)
    output = stdout.read().decode() + stderr.read().decode()
    exit_code = stdout.channel.recv_exit_status()
    if exit_code != 0:
        print(f"Error (exit code {exit_code}):")
    return output

def main():
    print("=" * 70)
    print("DEPLOYING MOJO NATIVE GPU SGP4")
    print("=" * 70)
    print(f"Connecting to {USERNAME}@{SERVER_IP}:{PORT}...")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(SERVER_IP, port=PORT, username=USERNAME, password=PASSWORD)
    
    # Upload Mojo GPU files
    print("\n✓ Uploading Mojo GPU files...")
    scp = paramiko.SFTPClient.from_transport(client.get_transport())
    
    mojo_files = [
        "sgp4_mojo_gpu_correct.mojo",
    ]
    
    base_path = Path("src/mojo")
    for file in mojo_files:
        local_file = base_path / file
        remote_file = f"{REMOTE_DIR}/src/mojo/{file}"
        print(f"  {file}")
        scp.put(str(local_file), remote_file)
    
    scp.close()
    
    # Check GPU availability
    print("\n" + "=" * 70)
    print("CHECKING GPU")
    print("=" * 70)
    output = run_command(client, "nvidia-smi --query-gpu=name,memory.total --format=csv,noheader")
    print(output)
    
    # Run benchmark
    print("\n" + "=" * 70)
    print("RUNNING MOJO GPU BENCHMARK")
    print("=" * 70)
    
    bench_cmd = f"cd {REMOTE_DIR}/src/mojo && {VENV_MOJO} sgp4_mojo_gpu_correct.mojo"
    output = run_command(client, bench_cmd)
    print(output)
    
    client.close()
    print("\n✓ Deployment complete!")

if __name__ == "__main__":
    main()
