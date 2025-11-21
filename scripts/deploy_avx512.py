#!/usr/bin/env python3
"""
Deploy and run AVX-512 benchmark on server
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
    sftp = client.open_sftp()
    
    print("="*70)
    print("DEPLOYING AVX-512 IMPLEMENTATION")
    print("="*70)
    
    # Upload files
    print("\n✓ Uploading AVX-512 files...")
    sftp.put("src/mojo/sgp4_avx512.mojo", f"{REMOTE_DIR}/src/mojo/sgp4_avx512.mojo")
    sftp.put("src/mojo/benchmark_avx512.mojo", f"{REMOTE_DIR}/src/mojo/benchmark_avx512.mojo")
    print("  sgp4_avx512.mojo")
    print("  benchmark_avx512.mojo")
    
    sftp.close()
    
    # Run benchmark
    print("\n" + "="*70)
    print("RUNNING AVX-512 BENCHMARK")
    print("="*70)
    
    benchmark_cmd = f"""
    cd {REMOTE_DIR}
    MOJO=$HOME/astrolabe/venv/bin/mojo
    echo "Compiling..."
    $MOJO build src/mojo/benchmark_avx512.mojo -o benchmark_avx512
    echo ""
    echo "Running..."
    ./benchmark_avx512
    """
    
    exit_code = run_command(client, benchmark_cmd, print_output=True)
    
    if exit_code != 0:
        print("\n✗ Benchmark failed")
    else:
        print("\n✓ Benchmark complete!")
    
    client.close()

if __name__ == "__main__":
    main()
