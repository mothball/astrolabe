#!/bin/bash

# Setup Cron Job for TLE Updates

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"

# Create logs directory
mkdir -p "$LOG_DIR"

# Define the cron job command
# Run daily at midnight
CRON_CMD="0 0 * * * cd $PROJECT_ROOT && source venv/bin/activate && python3 scripts/update_tles.py --source celestrak >> $LOG_DIR/update.log 2>&1"

# Check if cron job already exists
(crontab -l 2>/dev/null | grep -F "update_tles.py") && echo "Cron job already exists." && exit 0

# Add cron job
(crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
echo "Cron job added successfully."
echo "Logs will be written to: $LOG_DIR/update.log"
