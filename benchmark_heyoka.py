import time
import sys
import numpy as np
from sgp4.api import Satrec, SatrecArray, WGS72

def benchmark_all():
    num_satellites = 10000
    print(f"Satellites: {num_satellites}")
    
    # Initialize satellites (ISS-like orbit)
    print("Initializing satellites...")
    satrecs = []
    deg2rad = np.pi / 180.0
    no_kozai = 15.54 * 2.0 * np.pi / 1440.0
    inclo = 51.6 * deg2rad
    
    start_init = time.time()
    for i in range(num_satellites):
        s = Satrec()
        s.sgp4init(
            WGS72,
            'i',
            i,               # satnum
            0.0,             # epoch (unused)
            0.00001,         # bstar
            0.0,             # ndot (unused)
            0.0,             # nddot (unused)
            0.0001,          # ecco
            0.0,             # argpo
            inclo,           # inclo
            float(i) * 0.001,# mo
            no_kozai,        # no_kozai
            0.0,             # nodeo
        )
        satrecs.append(s)
    print(f"Initialization took {time.time() - start_init:.4f}s")

    # --- Heyoka Benchmark ---
    print("\n--- Heyoka Benchmark ---")
    try:
        import heyoka
        propagator = heyoka.model.sgp4_propagator(satrecs)
        
        start_time = time.time()
        # API requires a numpy array of times matching the number of satellites
        times = np.full(num_satellites, 100.0, dtype=np.float64)
        propagator(times)
        end_time = time.time()
        
        duration = end_time - start_time
        rate = num_satellites / duration
        print(f"Heyoka Results:")
        print(f"  Time: {duration:.6f} seconds")
        print(f"  Rate: {rate:.2f} props/sec")
    except ImportError:
        print("Heyoka not found")
    except Exception as e:
        print(f"Heyoka benchmark failed: {e}")

    # --- SGP4 Package Benchmark ---
    print("\n--- SGP4 Package Benchmark (SatrecArray) ---")
    try:
        satrecs_array = SatrecArray(satrecs)
        jd = np.zeros(num_satellites, dtype=np.float64)
        fr = np.full(num_satellites, 100.0 / 1440.0, dtype=np.float64)
        
        start = time.time()
        e, r, v = satrecs_array.sgp4(jd, fr)
        end = time.time()
        
        duration = end - start
        rate = num_satellites / duration
        print(f"SGP4 Results:")
        print(f"  Time: {duration:.6f} seconds")
        print(f"  Rate: {rate:.2f} props/sec")
        
    except Exception as e:
        print(f"SGP4 benchmark failed: {e}")

if __name__ == "__main__":
    benchmark_all()
