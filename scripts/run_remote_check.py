#!/usr/bin/env python3
"""
Run Remote DB Check
"""
import paramiko
import sys
from dotenv import load_dotenv

load_dotenv()

SERVER_IP = "173.79.187.44"
USERNAME = "sumanth"
PORT = 22222
PASSWORD = "LuckyChelli66@0@0"
REMOTE_DIR = "/home/sumanth/astrolabe"

def main():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(SERVER_IP, port=PORT, username=USERNAME, password=PASSWORD)
        
        cmd = f"cd {REMOTE_DIR} && source venv/bin/activate && python3 scripts/check_db.py"
        print(f"Running remote check: {cmd}")
        
        stdin, stdout, stderr = client.exec_command(cmd)
        exit_status = stdout.channel.recv_exit_status()
        
        if exit_status != 0:
            print("Error running remote check:")
            print(stderr.read().decode())
            sys.exit(1)
            
        print(stdout.read().decode())
        
    except Exception as e:
        print(f"Connection failed: {e}")
        sys.exit(1)
    finally:
        client.close()

if __name__ == "__main__":
    main()
