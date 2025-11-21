#!/bin/bash

# Setup Cron Job for TLE Updates

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"

# Create logs directory
mkdir -p "$LOG_DIR"

# Define the cron job command
# Run 4x a day (every 6 hours) at minute 23
CRON_CMD="23 */6 * * * cd $PROJECT_ROOT && source venv/bin/activate && python3 scripts/update_tles.py --source celestrak >> $LOG_DIR/update.log 2>&1"

# Remove existing job if it exists (to allow updates)
(crontab -l 2>/dev/null | grep -v "update_tles.py") | crontab -

# Add cron job
(crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
echo "Cron job updated successfully."
echo "Logs will be written to: $LOG_DIR/update.log"
