#!/usr/bin/env python3
"""
Install Mojo on home server and run benchmarks
"""
import paramiko
import sys
import time

SERVER_IP = "173.79.187.44"
USERNAME = "sumanth"
PORT = 22222
PASSWORD = "LuckyChelli66@0@0"
REMOTE_DIR = "/home/sumanth/mojo_sgp4_benchmark"

def create_ssh_client():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(SERVER_IP, port=PORT, username=USERNAME, password=PASSWORD, timeout=10)
    return client

def run_command(client, command, print_output=True, timeout=300):
    """Run command and return (exit_code, stdout, stderr)"""
    stdin, stdout, stderr = client.exec_command(command, timeout=timeout)
    
    # Read output in real-time
    if print_output:
        while True:
            line = stdout.readline()
            if not line:
                break
            print(line, end='')
    
    exit_status = stdout.channel.recv_exit_status()
    stdout_text = stdout.read().decode() if not print_output else ""
    stderr_text = stderr.read().decode()
    
    if stderr_text and exit_status != 0:
        print(f"Error: {stderr_text}", file=sys.stderr)
    
    return exit_status, stdout_text, stderr_text

def main():
    client = create_ssh_client()
    
    print("="*70)
    print("INSTALLING MOJO ON HOME SERVER")
    print("="*70)
    
    # Install Modular
    print("\n✓ Installing Modular CLI...")
    exit_code, _, _ = run_command(
        client,
        "curl -s https://get.modular.com | sh - 2>&1",
        print_output=True,
        timeout=600
    )
    
    if exit_code != 0:
        print("✗ Failed to install Modular")
        sys.exit(1)
    
    # Install Mojo
    print("\n✓ Installing Mojo...")
    exit_code, _, _ = run_command(
        client,
        "modular install mojo 2>&1",
        print_output=True,
        timeout=600
    )
    
    if exit_code != 0:
        print("✗ Failed to install Mojo")
        sys.exit(1)
    
    # Add to PATH and run benchmarks
    print("\n" + "="*70)
    print("RUNNING BENCHMARKS")
    print("="*70)
    
    # Set up environment and run
    benchmark_cmd = f"""
    export MODULAR_HOME="$HOME/.modular"
    export PATH="$MODULAR_HOME/pkg/packages.modular.com_mojo/bin:$PATH"
    cd {REMOTE_DIR}
    echo "Mojo version:"
    mojo --version
    echo ""
    echo "Running diagnostic..."
    mojo src/mojo/diagnostic_parallel.mojo
    echo ""
    echo "Running main benchmark..."
    mojo src/mojo/benchmark_max_performance.mojo
    """
    
    exit_code, _, _ = run_command(
        client,
        benchmark_cmd,
        print_output=True,
        timeout=600
    )
    
    print("\n" + "="*70)
    print("COMPLETE")
    print("="*70)
    
    client.close()

if __name__ == "__main__":
    main()
