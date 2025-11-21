#!/usr/bin/env python3
"""Compare Mojo SGP4 results with Python sgp4"""

from sgp4.api import Satrec, WGS72
import math

# Create a satellite with ISS-like elements
sat = Satrec()
sat.sgp4init(
    WGS72,           # gravity model
    'i',             # 'a' = old AFSPC mode, 'i' = improved mode
    0,               # satnum
    0.0,             # epoch time in days from jan 0, 1950. 0 hr
    0.00001,         # bstar (drag term)
    0.0,             # ndot (not used)
    0.0,             # nddot (not used)
    0.0001,          # ecco (eccentricity)
    0.0,             # argpo (argument of perigee, radians)
    51.6 * math.pi / 180.0,  # inclo (inclination, radians)
    0.0,             # mo (mean anomaly, radians)
    15.54 * 2.0 * math.pi / 1440.0,  # no_kozai (mean motion, rad/min)
    0.0,             # nodeo (right ascension of ascending node, radians)
)

# Propagate 100 minutes
e, r, v = sat.sgp4(0.0, 100.0)  # jd, fr (time in minutes)

print("Python SGP4 Results:")
print(f"Error code: {e}")
print(f"Position (km): {r}")
print(f"Velocity (km/s): {v}")
print(f"\nMagnitude:")
print(f"  |r| = {math.sqrt(r[0]**2 + r[1]**2 + r[2]**2):.2f} km")
print(f"  |v| = {math.sqrt(v[0]**2 + v[1]**2 + v[2]**2):.6f} km/s")
