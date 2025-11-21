#!/bin/bash

# Script to run TLE updates from home server
# Usage: ./run_home_server.sh [celestrak|spacetrack]

SOURCE=${1:-celestrak}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables if needed (or rely on system env)
if [ -f "$PROJECT_ROOT/.env" ]; then
  export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
fi

echo "Running TLE update from home server..."
echo "Source: $SOURCE"
echo "Date: $(date)"

# Run the python script
if [ -d "$PROJECT_ROOT/venv" ]; then
  "$PROJECT_ROOT/venv/bin/python" "$SCRIPT_DIR/update_tles.py" --source "$SOURCE"
else
  python3 "$SCRIPT_DIR/update_tles.py" --source "$SOURCE"
fi

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "Update completed successfully."
else
  echo "Update failed with exit code $EXIT_CODE."
fi

exit $EXIT_CODE
