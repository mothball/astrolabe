#!/usr/bin/env python3
"""
Verify Remote Cron Job
"""
import paramiko
import sys
from dotenv import load_dotenv

load_dotenv()

SERVER_IP = "173.79.187.44"
USERNAME = "sumanth"
PORT = 22222
PASSWORD = "LuckyChelli66@0@0"

def main():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(SERVER_IP, port=PORT, username=USERNAME, password=PASSWORD)
        
        cmd = "crontab -l"
        print(f"Running: {cmd}")
        
        stdin, stdout, stderr = client.exec_command(cmd)
        exit_status = stdout.channel.recv_exit_status()
        
        if exit_status != 0:
            print("Error running crontab -l:")
            print(stderr.read().decode())
            sys.exit(1)
            
        output = stdout.read().decode()
        print("\nRemote Crontab:")
        print("-" * 20)
        print(output)
        print("-" * 20)
        
        if "23 */6 * * *" in output:
            print("✅ Verification Successful: Cron job is set to run at minute 23 every 6 hours.")
        else:
            print("❌ Verification Failed: Expected schedule not found.")
            sys.exit(1)
        
    except Exception as e:
        print(f"Connection failed: {e}")
        sys.exit(1)
    finally:
        client.close()

if __name__ == "__main__":
    main()
