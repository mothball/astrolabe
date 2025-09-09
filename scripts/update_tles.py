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


def update_active_tles():
    """Update only active satellite TLEs"""
    print(f"Starting TLE update at {datetime.utcnow().isoformat()}")

    updater = TLEDatabaseUpdater()

    # Fetch latest active TLEs
    url = CELESTRAK_URLS['active']
    lines = updater.fetch_tle_data(url)

    if lines:
        updater.process_tles(lines, source='celestrak-daily')
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
    stats = update_active_tles()

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