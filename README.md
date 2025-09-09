# TLE Tracker 🛰️

A Python-based TLE (Two-Line Element) tracker

## Features

- 📡 Fetches TLE data from Celestrak
- 🗄️ Stores in PostgreSQL database
- 🔄 Automatic deduplication
- ⚡ Fast batch processing
- 🤖 GitHub Actions for daily updates
- 📊 Tracks statistics and history

## Setup

1. Clone the repository:
```bash
git clone https://github.com/mothball/astrolabe.git
cd astrolabe
```

2. Install dependencies with uv:
```bash
uv pip install -e .
```

3. Copy .env.example to .env and add your Supabase credentials:
```bash
cp .env.example .env
# Edit .env with your credentials
```

4. Run initial population:
```bash
python scripts/populate_tles.py
```

## Usage

### Populate Database
```bash
# Interactive mode
python scripts/populate_tles.py

# Or use as module
python -m scripts.populate_tles
```

### Update TLEs
```bash
python scripts/update_tles.py
```

### Automated Updates
This repository uses GitHub Actions to automatically update TLEs daily.

## Data Sources

- Active satellites from Celestrak
- Space stations
- Starlink constellation
- Visual satellites
- Last 30 days launches

## Database Schema

- satellites: Satellite metadata
- tles: Historical TLE records
- latest_tles: View of most recent TLE per satellite

## License

- MIT