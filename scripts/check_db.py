#!/usr/bin/env python3
"""
Check SQLite Database Statistics
"""
import os
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from astrolabe.database import TLEDatabaseUpdater
from astrolabe.config import DB_TYPE, DB_PATH

def main():
    if DB_TYPE != 'sqlite':
        print(f"Error: configured for {DB_TYPE}, but this script is for checking the local SQLite DB.")
        return 1

    if not os.path.exists(DB_PATH):
        print(f"Error: Database file not found at {DB_PATH}")
        return 1

    print(f"Checking database at: {DB_PATH}")
    
    updater = TLEDatabaseUpdater()
    stats = updater.get_database_stats()
    
    if stats:
        print("\nDATABASE STATISTICS")
        print("=" * 50)
        print(f"Total satellites: {stats.get('total_satellites', 'N/A')}")
        print(f"Active satellites: {stats.get('active_satellites', 'N/A')}")
        print(f"Total TLEs:       {stats.get('total_tles', 'N/A')}")
        print(f"Latest TLE Epoch: {stats.get('latest_tle_epoch', 'N/A')}")
        print("=" * 50)
        return 0
    else:
        print("Failed to retrieve statistics.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
