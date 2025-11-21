#!/usr/bin/env python3
"""
Profile Mojo SGP4 on server using perf
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
    """Run command and return exit code"""
    stdin, stdout, stderr = client.exec_command(command, get_pty=True, timeout=timeout)
    
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
    print("PROFILING MOJO SGP4 ON SERVER")
    print("="*70)
    
    # Install perf if needed
    print("\n✓ Installing profiling tools...")
    install_cmd = f"""
    if ! command -v perf &> /dev/null; then
        echo '{PASSWORD}' | sudo -S apt-get update
        echo '{PASSWORD}' | sudo -S apt-get install -y linux-tools-common linux-tools-generic linux-tools-$(uname -r)
    fi
    """
    run_command(client, install_cmd, print_output=True)
    
    # Compile benchmark to binary
    print("\n✓ Compiling benchmark...")
    compile_cmd = f"""
    cd {REMOTE_DIR}
    MOJO=$HOME/astrolabe/venv/bin/mojo
    $MOJO build src/mojo/benchmark_max_performance.mojo -o benchmark_max_performance
    """
    exit_code = run_command(client, compile_cmd, print_output=True)
    
    if exit_code != 0:
        print("✗ Failed to compile benchmark")
        sys.exit(1)
    
    # Run with perf record
    print("\n✓ Running perf record...")
    perf_cmd = f"""
    cd {REMOTE_DIR}
    echo '{PASSWORD}' | sudo -S perf record -F 999 -g --call-graph dwarf ./benchmark_max_performance
    """
    exit_code = run_command(client, perf_cmd, print_output=True, timeout=600)
    
    # Generate perf report
    print("\n✓ Generating perf report...")
    report_cmd = f"""
    cd {REMOTE_DIR}
    echo '{PASSWORD}' | sudo -S perf report --stdio -n --percent-limit 1 > perf_report.txt
    echo "Top 20 hotspots:"
    head -50 perf_report.txt
    """
    run_command(client, report_cmd, print_output=True)
    
    # Analyze cache misses
    print("\n✓ Analyzing cache performance...")
    cache_cmd = f"""
    cd {REMOTE_DIR}
    echo '{PASSWORD}' | sudo -S perf stat -e cache-references,cache-misses,L1-dcache-loads,L1-dcache-load-misses,LLC-loads,LLC-load-misses ./benchmark_max_performance 2>&1 | grep -E 'cache|LLC'
    """
    run_command(client, cache_cmd, print_output=True)
    
    # Download perf data
    print("\n✓ Downloading perf data...")
    sftp = client.open_sftp()
    try:
        sftp.get(f"{REMOTE_DIR}/perf_report.txt", "perf_report.txt")
        print("✓ Downloaded perf_report.txt")
    except Exception as e:
        print(f"Warning: Could not download perf data: {e}")
    finally:
        sftp.close()
    
    print("\n" + "="*70)
    print("PROFILING COMPLETE")
    print("="*70)
    print("\nNext steps:")
    print("1. Review perf_report.txt for hotspots")
    print("2. Identify optimization opportunities")
    print("3. Implement AVX-512 SIMD")
    
    client.close()

if __name__ == "__main__":
    main()
