import time
import random
from sgp4.api import Satrec, WGS72
from sgp4.api import jday

def benchmark_python(num_satellites=1000, duration_days=1):
    # Generate dummy TLEs (simplified for benchmark)
    # In a real scenario, we'd load real TLEs.
    # Here we just create one Satrec object and copy it or re-initialize it.
    
    # ISS TLE
    s = '1 25544U 98067A   19343.69339541  .00001764  00000-0  38792-4 0  9991'
    t = '2 25544  51.6439 211.2001 0007417  17.6667  85.6398 15.50103472202482'
    satellite = Satrec.twoline2rv(s, t, WGS72)
    
    satellites = [satellite] * num_satellites
    
    start_time = time.time()
    
    # Propagate for 'duration_days' with 1 minute steps
    # 1 day = 1440 minutes
    steps = duration_days * 1440
    
    jd, fr = jday(2019, 12, 9, 12, 0, 0)
    
    count = 0
    for sat in satellites:
        # We'll just propagate to a single point for now to test throughput of "many satellites"
        # Or propagate a series of points. Let's do a series of points for one satellite to test that loop,
        # and many satellites to test that loop.
        # Let's do: propagate all satellites to *one* timestamp (common use case: "where is everything right now?")
        
        e, r, v = sat.sgp4(jd, fr)
        count += 1
        
    end_time = time.time()
    
    print(f"Python SGP4 Benchmark")
    print(f"Satellites: {num_satellites}")
    print(f"Time: {end_time - start_time:.6f} seconds")
    print(f"Rate: {num_satellites / (end_time - start_time):.2f} props/sec")

if __name__ == "__main__":
    benchmark_python(num_satellites=100000)
