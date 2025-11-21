#!/usr/bin/env python3
"""Deploy and test GPU-accelerated SGP4 on server"""

import paramiko
import os
from pathlib import Path

# Server configuration
SERVER_IP = "173.79.187.44"
USERNAME = "sumanth"
PORT = 22222
PASSWORD = "LuckyChelli66@0@0"
REMOTE_DIR = "/home/sumanth/mojo_sgp4_benchmark"

def run_command(client, command):
    """Execute command on remote server"""
    print(f"Running: {command}")
    stdin, stdout, stderr = client.exec_command(command)
    output = stdout.read().decode() + stderr.read().decode()
    exit_code = stdout.channel.recv_exit_status()
    
    if exit_code != 0:
        print(f"Error (exit code {exit_code}):")
        print(output)
    return output

def main():
    print("=" * 70)
    print("DEPLOYING GPU SGP4 TO SERVER")
    print("=" * 70)
    print(f"Connecting to {USERNAME}@{SERVER_IP}:{PORT}...")
    
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(SERVER_IP, port=PORT, username=USERNAME, password=PASSWORD)
    
    # Create remote directories
    run_command(client, f"mkdir -p {REMOTE_DIR}/src/gpu")
    
    # Upload GPU files
    print("\n✓ Uploading GPU files...")
    scp = paramiko.SFTPClient.from_transport(client.get_transport())
    
    gpu_files = [
        "sgp4_kernel.cu",
        "sgp4_gpu.py",
        "diagnose_gpu.py",
        "README.md",
    ]
    
    base_path = Path("src/gpu")
    for file in gpu_files:
        local_file = base_path / file
        remote_file = f"{REMOTE_DIR}/src/gpu/{file}"
        print(f"  {file}")
        scp.put(str(local_file), remote_file)
    
    scp.close()
    
    # Check CUDA installation
    print("\n" + "=" * 70)
    print("CHECKING CUDA INSTALLATION")
    print("=" * 70)
    output = run_command(client, "nvcc --version")
    print(output)
    
    output = run_command(client, "nvidia-smi")
    print(output)
    
    # Define venv paths
    VENV_PYTHON = f"{REMOTE_DIR}/../astrolabe/venv/bin/python"
    VENV_PIP = f"{REMOTE_DIR}/../astrolabe/venv/bin/pip"
    
    # Install Python dependencies
    print("\n" + "=" * 70)
    print("INSTALLING PYTHON DEPENDENCIES")
    print("=" * 70)
    
    # Check if cupy is installed
    output = run_command(client, f"{VENV_PYTHON} -c 'import cupy; print(cupy.__version__)'")
    if "ModuleNotFoundError" in output or "No module" in output:
        print("Installing CuPy...")
        # Use venv pip
        run_command(client, f"{VENV_PIP} install cupy-cuda12x numpy")
    else:
        print(f"CuPy already installed: {output.strip()}")
    
    # Find CUDA libraries
    print("\n" + "=" * 70)
    print("CONFIGURING CUDA ENVIRONMENT")
    print("=" * 70)
    
    # Check common CUDA library paths
    cuda_lib_paths = [
        "/usr/local/cuda/lib64",
        "/usr/local/cuda-12/lib64",
        "/usr/local/cuda-13/lib64",
        "/usr/lib/x86_64-linux-gnu", 
    ]
    
    print("Searching for CUDA libraries...")
    for path in cuda_lib_paths:
        output = run_command(client, f"ls {path}/libcudart.so* 2>/dev/null || echo 'not found'")
        if "not found" not in output:
            print(f"  Found CUDA runtime in: {path}")
            print(f"  Setting LD_LIBRARY_PATH={path}")
            break
    
    # Run diagnostic
    print("\n" + "=" * 70)
    print("RUNNING GPU DIAGNOSTIC")
    print("=" * 70)
    
    diag_cmd = f"export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH && cd {REMOTE_DIR}/src/gpu && {VENV_PYTHON} diagnose_gpu.py"
    output = run_command(client, diag_cmd)
    print(output)
    
    # Run benchmark
    print("\n" + "=" * 70)
    print("RUNNING GPU BENCHMARK")
    print("=" * 70)
    
    # Set LD_LIBRARY_PATH and run
    bench_cmd = f"export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH && cd {REMOTE_DIR}/src/gpu && {VENV_PYTHON} sgp4_gpu.py"
    output = run_command(client, bench_cmd)
    print(output)
    
    client.close()
    print("\n✓ Deployment complete!")

if __name__ == "__main__":
    main()
