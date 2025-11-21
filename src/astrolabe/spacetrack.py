import requests
import time
from .config import SPACETRACK_IDENTITY, SPACETRACK_PASSWORD, SPACETRACK_URL, SPACETRACK_API_URL

class SpaceTrackClient:
    """Client for interacting with Space-Track API"""

    def __init__(self):
        self.session = requests.Session()
        self.authenticated = False

    def authenticate(self):
        """Authenticate with Space-Track"""
        if not SPACETRACK_IDENTITY or not SPACETRACK_PASSWORD:
            raise ValueError("Space-Track credentials not found in environment variables")

        payload = {
            'identity': SPACETRACK_IDENTITY,
            'password': SPACETRACK_PASSWORD,
        }

        print("Authenticating with Space-Track...")
        response = self.session.post(SPACETRACK_URL, data=payload)
        
        if response.status_code == 200:
            self.authenticated = True
            print("Successfully authenticated with Space-Track")
        else:
            raise Exception(f"Authentication failed: {response.status_code} - {response.text}")

    def fetch_tles(self):
        """Fetch TLE data from Space-Track"""
        if not self.authenticated:
            self.authenticate()

        print("Fetching TLE data from Space-Track...")
        # Fetching 3LE format which includes the satellite name
        response = self.session.get(SPACETRACK_API_URL)
        
        if response.status_code == 200:
            return response.text.strip().split('\n')
        else:
            raise Exception(f"Failed to fetch TLEs: {response.status_code} - {response.text}")
