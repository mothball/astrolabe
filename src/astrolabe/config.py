"""Configuration management for TLE Tracker"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env file if it exists
env_path = Path(__file__).parent.parent.parent / '.env'
load_dotenv(env_path)

# Supabase Configuration
SUPABASE_URL = os.environ.get('SUPABASE_URL', '')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY', '')

# Validate configuration
def validate_config():
    """Validate that required configuration is present"""
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError(
            "Missing Supabase configuration. "
            "Please set SUPABASE_URL and SUPABASE_KEY in .env file"
        )

# Celestrak URLs
CELESTRAK_URLS = {
    'active': 'https://celestrak.org/NORAD/elements/gp.php?GROUP=active&FORMAT=tle',
    'stations': 'https://celestrak.org/NORAD/elements/gp.php?GROUP=stations&FORMAT=tle',
    'last-30-days': 'https://celestrak.org/NORAD/elements/gp.php?GROUP=last-30-days&FORMAT=tle',
    'starlink': 'https://celestrak.org/NORAD/elements/gp.php?GROUP=starlink&FORMAT=tle',
    'visual': 'https://celestrak.org/NORAD/elements/gp.php?GROUP=visual&FORMAT=tle',
}