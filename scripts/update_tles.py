#!/usr/bin/env python3
"""
Scheduled TLE updater - run this daily via cron or GitHub Actions
Only fetches and adds new TLEs
"""

import sys
import json
from pathlib import Path
from datetime import datetime

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from astrolabe.database import TLEDatabaseUpdater
from astrolabe.config import CELESTRAK_URLS


import argparse

def update_active_tles(source='celestrak'):
    """Update only active satellite TLEs"""
    print(f"Starting TLE update at {datetime.utcnow().isoformat()} using source: {source}")

    updater = TLEDatabaseUpdater()

    # Fetch latest active TLEs
    if source == 'spacetrack':
        lines = updater.fetch_tle_data('spacetrack')
        source_name = 'spacetrack-daily'
    else:
        url = CELESTRAK_URLS['active']
        lines = updater.fetch_tle_data(url)
        source_name = 'celestrak-daily'

    if lines:
        updater.process_tles(lines, source=source_name)
        updater.print_stats()

        # Output GitHub Actions summary if in CI
        if sys.stdout.isatty() == False:  # Running in CI
            stats = updater.stats
            print(
                f"::notice title=TLE Update Complete::Added {stats['tles_added']} new TLEs, skipped {stats['tles_skipped']} duplicates")

        return updater.stats

    return None


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Update TLEs from Celestrak or Space-Track')
    parser.add_argument('--source', choices=['celestrak', 'spacetrack'], default='celestrak',
                        help='Source to fetch TLEs from (default: celestrak)')
    args = parser.parse_args()

    stats = update_active_tles(source=args.source)

    if stats:
        if stats['tles_added'] > 0:
            print(f"\n✅ Successfully added {stats['tles_added']} new TLEs")
        else:
            print("\nℹ️ No new TLEs to add (all up to date)")
        return 0
    else:
        print("\n❌ Failed to update TLEs")
        return 1


if __name__ == "__main__":
    sys.exit(main())