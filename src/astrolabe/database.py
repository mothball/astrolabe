"""Database operations for TLE tracker"""
import time
from typing import List, Dict, Optional
from supabase import create_client, Client
import requests

from .parser import TLEParser
from .config import SUPABASE_URL, SUPABASE_KEY, validate_config


class TLEDatabaseUpdater:
    """Handles all database operations for TLE data"""

    def __init__(self):
        """Initialize Supabase client"""
        validate_config()
        self.supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        self.parser = TLEParser()
        self.stats = {
            'satellites_added': 0,
            'satellites_updated': 0,
            'tles_added': 0,
            'tles_skipped': 0,
            'errors': 0
        }

    def fetch_tle_data(self, url: str) -> List[str]:
        """Fetch TLE data from Celestrak"""
        print(f"Fetching TLE data from: {url}")
        try:
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            return response.text.strip().split('\n')
        except Exception as e:
            print(f"Error fetching TLE data: {e}")
            return []

    def process_tles(self, lines: List[str], source: str = 'celestrak'):
        """Process TLE data and update database"""
        total_tles = len(lines) // 3
        print(f"Processing {total_tles} TLEs from {source}...")

        # Process in batches
        batch_size = 100
        satellites_batch = []
        tles_batch = []

        for i in range(0, len(lines), 3):
            if i + 2 >= len(lines):
                break

            name = lines[i].strip()
            line1 = lines[i + 1].strip()
            line2 = lines[i + 2].strip()

            # Validate checksums
            if not (self.parser.validate_checksum(line1) and
                    self.parser.validate_checksum(line2)):
                print(f"Invalid checksum for {name}")
                self.stats['errors'] += 1
                continue

            # Parse TLE
            tle_data = self.parser.parse_tle(name, line1, line2)
            if not tle_data:
                continue

            # Prepare satellite data
            satellite = {
                'norad_id': tle_data['norad_id'],
                'name': tle_data['name'],
                'international_designator': tle_data['international_designator'],
                'is_active': True
            }
            satellites_batch.append(satellite)

            # Prepare TLE data
            tle = {
                'norad_id': tle_data['norad_id'],
                'epoch': tle_data['epoch'],
                'tle_line1': tle_data['tle_line1'],
                'tle_line2': tle_data['tle_line2'],
                'inclination': tle_data['inclination'],
                'raan': tle_data['raan'],
                'eccentricity': tle_data['eccentricity'],
                'argument_of_perigee': tle_data['argument_of_perigee'],
                'mean_anomaly': tle_data['mean_anomaly'],
                'mean_motion': tle_data['mean_motion'],
                'revolution_number': tle_data['revolution_number'],
                'bstar': tle_data['bstar'],
                'mean_motion_dot': tle_data['mean_motion_dot'],
                'source': source
            }
            tles_batch.append(tle)

            # Process batch when full
            if len(satellites_batch) >= batch_size:
                self._update_database(satellites_batch, tles_batch)
                satellites_batch = []
                tles_batch = []
                print(f"  Processed {min(i + 3, len(lines))}/{len(lines)} lines...")

        # Process remaining items
        if satellites_batch:
            self._update_database(satellites_batch, tles_batch)

    def _update_database(self, satellites: List[Dict], tles: List[Dict]):
        """Update database with satellite and TLE data"""
        # Upsert satellites
        try:
            result = self.supabase.table('satellites').upsert(
                satellites,
                on_conflict='norad_id'
            ).execute()
            self.stats['satellites_updated'] += len(satellites)
        except Exception as e:
            print(f"Error updating satellites: {e}")
            self.stats['errors'] += 1

        # Insert TLEs (skip duplicates)
        for tle in tles:
            try:
                # Check if TLE already exists
                existing = self.supabase.table('tles').select('id').eq(
                    'norad_id', tle['norad_id']
                ).eq(
                    'epoch', tle['epoch']
                ).execute()

                if not existing.data:
                    # Insert new TLE
                    self.supabase.table('tles').insert(tle).execute()
                    self.stats['tles_added'] += 1
                else:
                    self.stats['tles_skipped'] += 1

            except Exception as e:
                # Likely a duplicate, skip
                self.stats['tles_skipped'] += 1

    def get_database_stats(self) -> Dict:
        """Get current database statistics"""
        try:
            # Use the stored function we created
            result = self.supabase.rpc('get_tle_stats').execute()
            if result.data and len(result.data) > 0:
                return result.data[0]
            return {}
        except Exception as e:
            print(f"Error getting stats: {e}")
            return {}

    def reset_stats(self):
        """Reset the statistics counter"""
        self.stats = {
            'satellites_added': 0,
            'satellites_updated': 0,
            'tles_added': 0,
            'tles_skipped': 0,
            'errors': 0
        }

    def print_stats(self):
        """Print update statistics"""
        print("\n" + "=" * 50)
        print("UPDATE STATISTICS")
        print("=" * 50)
        print(f"Satellites updated: {self.stats['satellites_updated']}")
        print(f"New TLEs added: {self.stats['tles_added']}")
        print(f"Duplicate TLEs skipped: {self.stats['tles_skipped']}")
        print(f"Errors: {self.stats['errors']}")

        # Get database stats
        db_stats = self.get_database_stats()
        if db_stats:
            print("\nDATABASE TOTALS")
            print("-" * 50)
            print(f"Total satellites: {db_stats.get('total_satellites', 'N/A')}")
            print(f"Active satellites: {db_stats.get('active_satellites', 'N/A')}")
            print(f"Total TLEs: {db_stats.get('total_tles', 'N/A')}")
            if db_stats.get('latest_tle_epoch'):
                print(f"Latest TLE: {db_stats.get('latest_tle_epoch', 'N/A')}")