#!/usr/bin/env python3
"""
Deploy Astrolabe to Home Server
"""
import os
import sys
import paramiko
from pathlib import Path
from dotenv import load_dotenv

# Load env to get credentials if they are there (optional, mostly for testing)
load_dotenv()

SERVER_IP = "173.79.187.44"
USERNAME = "sumanth"
PORT = 22222
PASSWORD = "LuckyChelli66@0@0"

REMOTE_DIR = "/home/sumanth/astrolabe"

def create_ssh_client():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        print(f"Connecting to {USERNAME}@{SERVER_IP}:{PORT}...")
        client.connect(SERVER_IP, port=PORT, username=USERNAME, password=PASSWORD)
        return client
    except Exception as e:
        print(f"Failed to connect: {e}")
        sys.exit(1)

def run_command(client, command):
    print(f"Running: {command}")
    stdin, stdout, stderr = client.exec_command(command)
    exit_status = stdout.channel.recv_exit_status()
    if exit_status != 0:
        print(f"Error running command: {command}")
        print(stderr.read().decode())
        return False
    print(stdout.read().decode())
    return True

def deploy():
    client = create_ssh_client()
    sftp = client.open_sftp()

    # 1. Create directory structure
    print("Creating remote directories...")
    run_command(client, f"mkdir -p {REMOTE_DIR}/src/astrolabe")
    run_command(client, f"mkdir -p {REMOTE_DIR}/scripts")

    # 2. Copy files
    local_root = Path(__file__).parent.parent
    
    files_to_copy = [
        ('pyproject.toml', 'pyproject.toml'),
        ('README.md', 'README.md'),
        ('src/astrolabe/__init__.py', 'src/astrolabe/__init__.py'),
        ('src/astrolabe/config.py', 'src/astrolabe/config.py'),
        ('src/astrolabe/database.py', 'src/astrolabe/database.py'),
        ('src/astrolabe/parser.py', 'src/astrolabe/parser.py'),
        ('src/astrolabe/spacetrack.py', 'src/astrolabe/spacetrack.py'),
        ('scripts/update_tles.py', 'scripts/update_tles.py'),
        ('scripts/check_db.py', 'scripts/check_db.py'),
        ('scripts/setup_cron.sh', 'scripts/setup_cron.sh'),
    ]

    print("Copying files...")
    for local, remote in files_to_copy:
        local_path = local_root / local
        remote_path = f"{REMOTE_DIR}/{remote}"
        if local_path.exists():
            print(f"  {local} -> {remote}")
            sftp.put(str(local_path), remote_path)
            # Make shell scripts executable
            if remote.endswith('.sh'):
                run_command(client, f"chmod +x {remote_path}")
        else:
            print(f"Warning: Local file not found: {local_path}")

    # 3. Create .env file
    print("Creating .env file...")
    env_content = f"""
DB_TYPE=sqlite
DB_PATH={REMOTE_DIR}/astrolabe.db
"""
    with sftp.file(f"{REMOTE_DIR}/.env", "w") as f:
        f.write(env_content)

    # 3.5 Install system dependencies (if needed)
    print("Installing system dependencies...")
    # Try to install python3-venv if missing
    install_cmd = f"echo '{PASSWORD}' | sudo -S apt-get update && echo '{PASSWORD}' | sudo -S apt-get install -y python3-venv"
    run_command(client, install_cmd)

    # 4. Setup Virtual Environment and Install Dependencies
    print("Setting up environment...")
    # Split commands to identify failure
    if not run_command(client, f"cd {REMOTE_DIR} && python3 -m venv venv"):
        print("Failed to create venv")
        sys.exit(1)
        
    setup_cmd = f"""
    cd {REMOTE_DIR} && \
    source venv/bin/activate && \
    pip install .
    """
    if not run_command(client, setup_cmd):
        print("Failed to setup environment")
        sys.exit(1)

    # 5. Setup Cron Job
    print("Setting up cron job...")
    cron_cmd = f"""
    cd {REMOTE_DIR} && \
    ./scripts/setup_cron.sh
    """
    if not run_command(client, cron_cmd):
        print("Failed to setup cron job")
        sys.exit(1)

    print("Deployment and automation setup complete!")
    client.close()

if __name__ == "__main__":
    deploy()
