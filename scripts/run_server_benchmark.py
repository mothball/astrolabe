#!/usr/bin/env python3
"""
Run benchmarks on server (assumes Mojo is already installed)
"""
import paramiko
import sys

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

def run_command(client, command, print_output=True):
    """Run command and return exit code"""
    stdin, stdout, stderr = client.exec_command(command, get_pty=True)
    
    if print_output:
        while True:
            line = stdout.readline()
            if not line:
                break
            print(line, end='')
    
    exit_status = stdout.channel.recv_exit_status()
    return exit_status

def main():
    client = create_ssh_client()
    
    print("="*70)
    print("RUNNING BENCHMARKS ON AMD RYZEN 9 9950X3D (32 CORES)")
    print("="*70)
    
    # Use mojo from astrolabe venv
    benchmark_cmd = f"""
    cd {REMOTE_DIR}
    
    # Check if mojo is in astrolabe venv
    if [ -f "$HOME/astrolabe/venv/bin/mojo" ]; then
        echo "✓ Mojo found in ~/astrolabe/venv"
        MOJO="$HOME/astrolabe/venv/bin/mojo"
        $MOJO --version
    elif command -v mojo &> /dev/null; then
        echo "✓ Mojo found in PATH"
        MOJO="mojo"
        $MOJO --version
    else
        echo "✗ Mojo not found!"
        echo "Expected at: $HOME/astrolabe/venv/bin/mojo"
        exit 1
    fi
    
    echo ""
    echo "Running diagnostic..."
    $MOJO src/mojo/diagnostic_parallel.mojo
    
    echo ""
    echo "Running main benchmark..."
    $MOJO src/mojo/benchmark_max_performance.mojo
    """
    
    exit_code = run_command(client, benchmark_cmd, print_output=True)
    
    if exit_code != 0:
        print("\n" + "="*70)
        print("MOJO NOT INSTALLED - MANUAL INSTALLATION REQUIRED")
        print("="*70)
        print("\nPlease run these commands on your server:")
        print(f"  ssh -p {PORT} {USERNAME}@{SERVER_IP}")
        print("  curl -s https://get.modular.com | sh -")
        print("  source ~/.bashrc")
        print("  modular auth <YOUR_MODULAR_KEY>")
        print("  modular install mojo")
        print("\nThen re-run this script.")
    else:
        print("\n" + "="*70)
        print("BENCHMARKS COMPLETE!")
        print("="*70)
    
    client.close()

if __name__ == "__main__":
    main()
