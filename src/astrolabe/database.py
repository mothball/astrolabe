"""Database operations for TLE tracker"""
import time
import sqlite3
from typing import List, Dict, Optional, Any
from abc import ABC, abstractmethod
from pathlib import Path
from supabase import create_client, Client
import requests

from .parser import TLEParser
from .config import (
    SUPABASE_URL, SUPABASE_KEY, DB_TYPE, DB_PATH, validate_config
)
from .spacetrack import SpaceTrackClient


class DatabaseBackend(ABC):
    """Abstract base class for database backends"""
    
    @abstractmethod
    def upsert_satellites(self, satellites: List[Dict]) -> int:
        """Upsert satellites and return count of updated rows"""
        pass

    @abstractmethod
    def insert_tles(self, tles: List[Dict]) -> int:
        """Insert TLEs and return count of added rows (skipping duplicates)"""
        pass

    @abstractmethod
    def get_stats(self) -> Dict:
        """Get database statistics"""
        pass


class SupabaseBackend(DatabaseBackend):
    """Supabase implementation of database backend"""

    def __init__(self):
        self.supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    def upsert_satellites(self, satellites: List[Dict]) -> int:
        try:
            self.supabase.table('satellites').upsert(
                satellites,
                on_conflict='norad_id'
            ).execute()
            return len(satellites)
        except Exception as e:
            print(f"Error updating satellites: {e}")
            raise

    def insert_tles(self, tles: List[Dict]) -> int:
        added_count = 0
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
                    added_count += 1
            except Exception:
                # Likely a duplicate, skip
                pass
        return added_count

    def get_stats(self) -> Dict:
        try:
            result = self.supabase.rpc('get_tle_stats').execute()
            if result.data and len(result.data) > 0:
                return result.data[0]
            return {}
        except Exception as e:
            print(f"Error getting stats: {e}")
            return {}


class SQLiteBackend(DatabaseBackend):
    """SQLite implementation of database backend"""

    def __init__(self, db_path: str):
        self.db_path = db_path
        self._init_db()

    def _init_db(self):
        """Initialize database schema"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS satellites (
                    norad_id INTEGER PRIMARY KEY,
                    name TEXT,
                    international_designator TEXT,
                    is_active BOOLEAN DEFAULT 1,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS tles (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    norad_id INTEGER,
                    epoch TIMESTAMP,
                    tle_line1 TEXT,
                    tle_line2 TEXT,
                    inclination REAL,
                    raan REAL,
                    eccentricity REAL,
                    argument_of_perigee REAL,
                    mean_anomaly REAL,
                    mean_motion REAL,
                    revolution_number INTEGER,
                    bstar REAL,
                    mean_motion_dot REAL,
                    source TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(norad_id, epoch),
                    FOREIGN KEY(norad_id) REFERENCES satellites(norad_id)
                )
            """)
            conn.commit()

    def upsert_satellites(self, satellites: List[Dict]) -> int:
        count = 0
        with sqlite3.connect(self.db_path) as conn:
            for sat in satellites:
                try:
                    conn.execute("""
                        INSERT INTO satellites (norad_id, name, international_designator, is_active)
                        VALUES (?, ?, ?, ?)
                        ON CONFLICT(norad_id) DO UPDATE SET
                            name=excluded.name,
                            international_designator=excluded.international_designator,
                            is_active=excluded.is_active,
                            updated_at=CURRENT_TIMESTAMP
                    """, (
                        sat['norad_id'],
                        sat['name'],
                        sat['international_designator'],
                        sat['is_active']
                    ))
                    count += 1
                except Exception as e:
                    print(f"Error upserting satellite {sat['norad_id']}: {e}")
        return count

    def insert_tles(self, tles: List[Dict]) -> int:
        added_count = 0
        with sqlite3.connect(self.db_path) as conn:
            for tle in tles:
                try:
                    conn.execute("""
                        INSERT INTO tles (
                            norad_id, epoch, tle_line1, tle_line2,
                            inclination, raan, eccentricity, argument_of_perigee,
                            mean_anomaly, mean_motion, revolution_number,
                            bstar, mean_motion_dot, source
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        tle['norad_id'], tle['epoch'], tle['tle_line1'], tle['tle_line2'],
                        tle['inclination'], tle['raan'], tle['eccentricity'], tle['argument_of_perigee'],
                        tle['mean_anomaly'], tle['mean_motion'], tle['revolution_number'],
                        tle['bstar'], tle['mean_motion_dot'], tle['source']
                    ))
                    added_count += 1
                except sqlite3.IntegrityError:
                    # Duplicate
                    pass
                except Exception as e:
                    print(f"Error inserting TLE: {e}")
        return added_count

    def get_stats(self) -> Dict:
        stats = {}
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                
                cursor.execute("SELECT COUNT(*) FROM satellites")
                stats['total_satellites'] = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) FROM satellites WHERE is_active = 1")
                stats['active_satellites'] = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) FROM tles")
                stats['total_tles'] = cursor.fetchone()[0]
                
                cursor.execute("SELECT MAX(epoch) FROM tles")
                stats['latest_tle_epoch'] = cursor.fetchone()[0]
                
        except Exception as e:
            print(f"Error getting stats: {e}")
        return stats


class TLEDatabaseUpdater:
    """Handles all database operations for TLE data"""

    def __init__(self):
        """Initialize database backend"""
        validate_config()
        
        if DB_TYPE == 'sqlite':
            print(f"Using SQLite backend: {DB_PATH}")
            self.backend = SQLiteBackend(DB_PATH)
        else:
            print("Using Supabase backend")
            self.backend = SupabaseBackend()
            
        self.parser = TLEParser()
        self.spacetrack_client = None
        self.stats = {
            'satellites_added': 0,
            'satellites_updated': 0,
            'tles_added': 0,
            'tles_skipped': 0,
            'errors': 0
        }

    def fetch_tle_data(self, source_url_or_type: str) -> List[str]:
        """Fetch TLE data from Celestrak or Space-Track"""
        if source_url_or_type == 'spacetrack':
            if not self.spacetrack_client:
                self.spacetrack_client = SpaceTrackClient()
            return self.spacetrack_client.fetch_tles()
        
        # Default to Celestrak (URL provided)
        url = source_url_or_type
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
        try:
            updated = self.backend.upsert_satellites(satellites)
            self.stats['satellites_updated'] += updated
        except Exception as e:
            self.stats['errors'] += 1

        try:
            added = self.backend.insert_tles(tles)
            self.stats['tles_added'] += added
            self.stats['tles_skipped'] += (len(tles) - added)
        except Exception as e:
            self.stats['errors'] += 1

    def get_database_stats(self) -> Dict:
        """Get current database statistics"""
        return self.backend.get_stats()

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