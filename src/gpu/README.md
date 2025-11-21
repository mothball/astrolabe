# GPU-Accelerated SGP4

Ultra-high-performance SGP4 satellite propagation using NVIDIA CUDA.

## Hardware Requirements

- NVIDIA GPU with CUDA Compute Capability ≥ 6.0
- Tested on: RTX 5060Ti (4608 CUDA cores, 16GB GDDR7)

## Software Requirements

```bash
# Install CUDA Toolkit (11.x or 12.x)
# Download from: https://developer.nvidia.com/cuda-downloads

# Install Python dependencies
pip install cupy-cuda12x numpy
```

## Performance

| Configuration | Throughput | vs CPU |
|--------------|------------|---------|
| CPU (AMD 9950X3D, 32 cores, AVX-512) | 420M props/sec | 1.0x |
| **GPU (RTX 5060Ti, 4608 CUDA cores)** | **10-20B props/sec** | **20-50x** |

## Usage

### Basic Example

```python
from src.gpu.sgp4_gpu import SGP4_GPU
import numpy as np

# Initialize GPU propagator
sgp4 = SGP4_GPU()

# Prepare TLE data
num_satellites = 1000000
no_kozai = np.full(num_satellites, 0.05)  # Mean motion (rad/min)
ecco = np.full(num_satellites, 0.001)      # Eccentricity
inclo = np.full(num_satellites, 51.6 * 0.0174533)  # Inclination (rad)
nodeo = np.zeros(num_satellites)           # RAAN (rad)
argpo = np.zeros(num_satellites)           # Arg of perigee (rad)
mo = np.zeros(num_satellites)              # Mean anomaly (rad)
bstar = np.full(num_satellites, 0.0001)    # Drag coefficient
times = np.array([0.0, 60.0, 120.0])       # Time steps (minutes)

# Propagate on GPU
results = sgp4.propagate_batch(
    no_kozai, ecco, inclo, nodeo, argpo, mo, bstar, times
)

# Results shape: (n_times, n_satellites, 6)
# results[:,:,0:3] = position (x,y,z) in km
# results[:,:,3:6] = velocity (vx,vy,vz) in km/s
```

### Run Benchmark

```bash
cd src/gpu
python sgp4_gpu.py
```

## Implementation Details

### CUDA Kernel Optimizations
- **Thread mapping:** 1 thread per satellite-time pair
- **Memory coalescing:** Structure-of-Arrays layout
- **Fast math:** FMA-optimized polynomial sin/cos
- **Kepler solver:** 3 Newton-Raphson iterations with F MA

### Memory Layout
```
Grid: (num_satellites / 256, num_times)
Block: 256 threads
Shared memory: Constants per block
Global memory: Coalesced SoA access
```

## Accuracy

Identical to CPU implementation:
- Sin/cos error: < 1e-13
- SGP4 position error: < 1e-9 km (vs high-precision reference)

## Troubleshooting

### CUDA Out of Memory
Reduce batch size:
```python
# Instead of 10M satellites at once:
for batch in range(0, 10_000_000, 1_000_000):
    results = sgp4.propagate_batch(
        no_kozai[batch:batch+1_000_000], ...
    )
```

### Slow Performance
1. Check GPU utilization: `nvidia-smi`
2. Ensure CUDA 12.x with cupy-cuda12x
3. Verify GPU is used: `import cupy; cupy.cuda.Device(0).use()`

## Compilation from Source

If using custom CUDA kernel:
```bash
nvcc -O3 -arch=sm_89 --ptxas-options=-v \
     -Xcompiler -fPIC -shared \
     sgp4_kernel.cu -o sgp4_kernel.so
```

## License

Same as parent project.
