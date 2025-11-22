import paramiko
import sys
import time
import os

SERVER_IP = "173.79.187.44"
USERNAME = "sumanth"
PORT = 22222
PASSWORD = "LuckyChelli66@0@0"

FILES_TO_UPLOAD = [
    "benchmark_comparison.py",
    "benchmark_heyoka.py",
    "inspect_heyoka.py",
    "src/mojo/benchmark_adaptive.mojo",
    "src/mojo/sgp4_adaptive.mojo",
    "src/mojo/fast_math_optimized.mojo"
]

REMOTE_DIR = "/home/sumanth/mojo_sgp4_benchmark"

def run_remote_benchmark():
    print(f"Connecting to {SERVER_IP}:{PORT}...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(SERVER_IP, port=PORT, username=USERNAME, password=PASSWORD)
        print("Connected successfully.")
        
        sftp = client.open_sftp()
        
        # Create remote directory if it doesn't exist
        try:
            sftp.mkdir(REMOTE_DIR)
            print(f"Created remote directory: {REMOTE_DIR}")
        except IOError:
            pass # Directory likely exists
            
        # Create src/mojo subdirectory
        try:
            sftp.mkdir(f"{REMOTE_DIR}/src")
        except IOError: pass
        try:
            sftp.mkdir(f"{REMOTE_DIR}/src/mojo")
        except IOError: pass

        # Upload files
        print("Uploading benchmark files...")
        for local_file in FILES_TO_UPLOAD:
            remote_file = f"{REMOTE_DIR}/{local_file}"
            if local_file.startswith("src/mojo/"):
                # Ensure local path exists
                if os.path.exists(local_file):
                    print(f"  Uploading {local_file} -> {remote_file}")
                    sftp.put(local_file, remote_file)
                else:
                    print(f"  Warning: Local file {local_file} not found!")
            else:
                if os.path.exists(local_file):
                    print(f"  Uploading {local_file} -> {remote_file}")
                    sftp.put(local_file, remote_file)
                else:
                    print(f"  Warning: Local file {local_file} not found!")
        
        sftp.close()
        print("Upload complete.")
        
        # Command to run the benchmark
        cmd = f"cd {REMOTE_DIR} && /home/sumanth/astrolabe/venv/bin/python benchmark_comparison.py"
        
        print(f"Executing: {cmd}")
        stdin, stdout, stderr = client.exec_command(cmd)
        
        # Stream output
        while not stdout.channel.exit_status_ready():
            if stdout.channel.recv_ready():
                output = stdout.channel.recv(1024).decode('utf-8')
                sys.stdout.write(output)
                sys.stdout.flush()
            if stderr.channel.recv_ready():
                err = stderr.channel.recv(1024).decode('utf-8')
                sys.stderr.write(err)
                sys.stderr.flush()
            time.sleep(0.1)
            
        print(stdout.read().decode('utf-8'))
        print(stderr.read().decode('utf-8'))
        
        exit_status = stdout.channel.recv_exit_status()
        print(f"\nCommand finished with exit status: {exit_status}")
        
    except Exception as e:
        print(f"Connection failed: {e}")
    finally:
        client.close()

if __name__ == "__main__":
    run_remote_benchmark()
