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
    "src/mojo/sgp4_adaptive_halley.mojo",
    "src/mojo/benchmark_adaptive_halley.mojo",
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
        
        # Run benchmark
        print("=" * 60)
        print("Halley's Method - 100k Satellites")
        print("=" * 60)
        cmd = f"cd {REMOTE_DIR} && /home/sumanth/astrolabe/venv/bin/mojo src/mojo/benchmark_adaptive_halley.mojo"
        stdin, stdout, stderr = client.exec_command(cmd)
        output = stdout.read().decode('utf-8')
        print(output)
        
        # Extract rate
        match = re.search(r"Rate:\s+([\d\.e\+]+)\s+props/sec", output)
        if match:
            rate = float(match.group(1))
            print("\n" + "=" * 60)
            print(f"RESULT: {rate:,.0f} props/sec")
            print("=" * 60)
            
            if rate > 350_000_000:
                print(f"✅ Reproduced high performance!")
            elif rate > 250_000_000:
                print(f"✓ Good performance")
            else:
                print(f"⚠️ Lower than expected")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        client.close()

if __name__ == "__main__":
    deploy_and_run()
