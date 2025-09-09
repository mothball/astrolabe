#!/usr/bin/env python3
"""
TLE Database Populator for Supabase
Fetches TLE data from Celestrak and updates Supabase database
"""

import sys
import time
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from astrolabe.database import TLEDatabaseUpdater
from astrolabe.config import CELESTRAK_URLS


def main():
    """Main function to populate TLE database"""
    print("TLE Database Populator")
    print("=" * 50)

    # Initialize updater
    updater = TLEDatabaseUpdater()

    # Choose data source
    print("\nAvailable data sources:")
    for i, (key, url) in enumerate(CELESTRAK_URLS.items(), 1):
        print(f"{i}. {key}")

    choice = input("\nSelect source (1-5) or 'all' for all sources: ").strip()

    if choice.lower() == 'all':
        # Process all sources
        for key, url in CELESTRAK_URLS.items():
            print(f"\n\nProcessing {key}...")
            lines = updater.fetch_tle_data(url)
            if lines:
                updater.process_tles(lines, source=key)
            time.sleep(2)  # Be nice to Celestrak servers
    else:
        # Process single source
        try:
            idx = int(choice) - 1
            key = list(CELESTRAK_URLS.keys())[idx]
            url = CELESTRAK_URLS[key]
            lines = updater.fetch_tle_data(url)
            if lines:
                updater.process_tles(lines, source=key)
        except (ValueError, IndexError):
            print("Invalid choice")
            return 1

    # Print statistics
    updater.print_stats()
    return 0


if __name__ == "__main__":
    sys.exit(main())