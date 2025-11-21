#!/usr/bin/env python3
"""
Deploy Mojo SGP4 benchmarks to home server and run them
"""
import paramiko
import sys
from pathlib import Path

SERVER_IP = "173.79.187.44"
USERNAME = "sumanth"
PORT = 22222
PASSWORD = "LuckyChelli66@0@0"
REMOTE_DIR = "/home/sumanth/mojo_sgp4_benchmark"

def create_ssh_client():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        print(f"Connecting to {USERNAME}@{SERVER_IP}:{PORT}...")
        client.connect(SERVER_IP, port=PORT, username=USERNAME, password=PASSWORD, timeout=10)
        print("✓ Connected!")
        return client
    except Exception as e:
        print(f"✗ Failed to connect: {e}")
        sys.exit(1)

def run_command(client, command, print_output=True):
    """Run command and return (exit_code, stdout, stderr)"""
    stdin, stdout, stderr = client.exec_command(command)
    exit_status = stdout.channel.recv_exit_status()
    stdout_text = stdout.read().decode()
    stderr_text = stderr.read().decode()
    
    if print_output and stdout_text:
        print(stdout_text)
    if stderr_text and exit_status != 0:
        print(f"Error: {stderr_text}", file=sys.stderr)
    
    return exit_status, stdout_text, stderr_text

def main():
    client = create_ssh_client()
    sftp = client.open_sftp()
    
    # 1. Get server info
    print("\n" + "="*70)
    print("SERVER HARDWARE INFO")
    print("="*70)
    
    exit_code, output, _ = run_command(client, "uname -m")
    arch = output.strip()
    print(f"Architecture: {arch}")
    
    exit_code, output, _ = run_command(client, "nproc")
    cores = output.strip()
    print(f"CPU Cores: {cores}")
    
    exit_code, output, _ = run_command(client, "cat /proc/cpuinfo | grep 'model name' | head -1")
    if output:
        cpu_model = output.split(':')[1].strip() if ':' in output else output.strip()
        print(f"CPU Model: {cpu_model}")
    
    # 2. Create directory
    print(f"\n✓ Creating directory {REMOTE_DIR}...")
    run_command(client, f"mkdir -p {REMOTE_DIR}/src/mojo", print_output=False)
    
    # 3. Copy Mojo files
    print("\n✓ Copying Mojo files...")
    local_root = Path(__file__).parent.parent
    
    mojo_files = [
        'src/mojo/sgp4_max_performance.mojo',
        'src/mojo/benchmark_max_performance.mojo',
        'src/mojo/diagnostic_parallel.mojo',
    ]
    
    for mojo_file in mojo_files:
        local_path = local_root / mojo_file
        remote_path = f"{REMOTE_DIR}/{mojo_file}"
        if local_path.exists():
            print(f"  {mojo_file}")
            sftp.put(str(local_path), remote_path)
        else:
            print(f"  Warning: {local_path} not found")
    
    # 4. Check if Mojo is installed
    print("\n✓ Checking for Mojo installation...")
    exit_code, output, _ = run_command(client, "which mojo", print_output=False)
    
    if exit_code != 0:
        print("✗ Mojo not found on server!")
        print("\nTo install Mojo on your server:")
        print("  1. SSH to your server: ssh -p 22222 sumanth@173.79.187.44")
        print("  2. Install Modular: curl -s https://get.modular.com | sh -")
        print("  3. Install Mojo: modular install mojo")
        print("\nThen re-run this script.")
        client.close()
        sys.exit(1)
    else:
        mojo_path = output.strip()
        print(f"✓ Mojo found at: {mojo_path}")
        
        # Get Mojo version
        exit_code, output, _ = run_command(client, "mojo --version", print_output=False)
        if exit_code == 0:
            print(f"  Version: {output.strip()}")
    
    # 5. Run diagnostic
    print("\n" + "="*70)
    print("RUNNING DIAGNOSTIC")
    print("="*70)
    
    exit_code, output, stderr = run_command(
        client, 
        f"cd {REMOTE_DIR} && mojo src/mojo/diagnostic_parallel.mojo",
        print_output=True
    )
    
    if exit_code != 0:
        print(f"\n✗ Diagnostic failed with exit code {exit_code}")
        if stderr:
            print(f"Error: {stderr}")
    
    # 6. Run main benchmark
    print("\n" + "="*70)
    print("RUNNING MAIN BENCHMARK")
    print("="*70)
    
    exit_code, output, stderr = run_command(
        client,
        f"cd {REMOTE_DIR} && mojo src/mojo/benchmark_max_performance.mojo",
        print_output=True
    )
    
    if exit_code != 0:
        print(f"\n✗ Benchmark failed with exit code {exit_code}")
        if stderr:
            print(f"Error: {stderr}")
    
    print("\n" + "="*70)
    print("DEPLOYMENT AND BENCHMARKING COMPLETE")
    print("="*70)
    
    client.close()

if __name__ == "__main__":
    main()
