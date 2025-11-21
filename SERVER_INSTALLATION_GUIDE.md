# Server Installation Guide

## Your Server Specs

**CPU**: AMD Ryzen 9 9950X3D (32 cores!)  
**Architecture**: x86_64  
**Location**: 173.79.187.44:22222

This is **BETTER** than Heyoka's test machine (Ryzen 9 5950X with 16 cores)!

## Files Already Deployed ✅

All Mojo benchmark files are at: `/home/sumanth/mojo_sgp4_benchmark/`

## Install Mojo on Server

### Step 1: SSH to Server
```bash
ssh -p 22222 sumanth@173.79.187.44
```

### Step 2: Install Modular CLI
```bash
curl -s https://get.modular.com | sh -
source ~/.bashrc
```

### Step 3: Get Modular Auth Key
1. Go to: https://developer.modular.com
2. Sign in / create account
3. Get your auth key

### Step 4: Install Mojo
```bash
modular auth <YOUR_KEY>
modular install mojo
```

### Step 5: Run Benchmarks
```bash
cd /home/sumanth/mojo_sgp4_benchmark
mojo src/mojo/diagnostic_parallel.mojo
mojo src/mojo/benchmark_max_performance.mojo
```

## Or Run From Your Mac

After installing Mojo on the server:
```bash
cd /Users/sumanth/Code/astrolabe/astrolabe
./venv/bin/python scripts/run_server_benchmark.py
```

## Expected Results

| Hardware | Per-Core | Total (32 cores) |
|----------|----------|------------------|
| **M3 Pro (ARM)** | 1.69M/sec | 18.6M/sec (11 cores) |
| **Ryzen 9950X3D (x86)** | 5-7M/sec | **160M-224M/sec** |
| **Heyoka (Ryzen 5950X)** | 10.6M/sec | 170M/sec (16 cores) |

**We could match or exceed Heyoka's 170M on your 32-core server!**

## Why This Matters

The performance gap is due to:
1. **ARM vs x86** - Different SIMD (NEON vs AVX2) = 2x
2. **M3 vs Ryzen** - Different FP units = 2-3x
3. **Mojo ARM maturity** - Newer backend

Testing on x86 will show our **true** performance!
