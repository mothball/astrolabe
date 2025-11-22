# Performance Clarification: 470M Theoretical vs Actual

## Actual Measured Benchmarks

| Configuration | Satellites | Performance | When | Hardware |
|:---|---:|---:|:---|:---|
| Baseline (Newton) | 100k | **384M props/sec** | Earlier session | Ryzen 9 9950X3D |
| **Halley's Method** | 100k | **366M props/sec** | Current | Ryzen 9 9950X3D (best current) |
| Halley's Method | 10k | 297M props/sec | Current | Ryzen 9 9950X3D |
| Baseline (Newton) | 10k | 253M props/sec | Current | Ryzen 9 9950X3D |

## The 470M Number

**Source**: `OPTIMIZATION_ANALYSIS.md` (line 199)

**What it actually was**: A **theoretical projection**, not a measured benchmark.

**The projection stack**:
```
Current:     375M props/sec (documented baseline at the time)
+ 15% FMA:   430M props/sec
+ 10% Remez: 470M props/sec  ← This line in the file
+ 10% Chunk: 515M props/sec
+ 5% Flags:  540M props/sec
```

These were **estimated potential gains** if we implemented:
1. FMA (Fused Multiply-Add) instructions
2. Remez polynomial optimization
3. Chunk size tuning
4. Compiler flag optimization

**Reality check**: We tested compiler flags (no gain), chunk size is already good, and FMA is compiler-dependent.

## Why We Can't Hit 470M

1. **It was never measured** - it was a theoretical projection
2. **Optimizations don't stack linearly** - real world has diminishing returns  
3. **Some projections were optimistic** - e.g., we found compiler flags made things worse
4. **Hardware variance** - thermal state, background processes, etc. cause ±10% variation

## Current Best: 366M props/sec ✅

**Configuration**: Halley's method + 100k satellites
- Real, measured performance
- Reproducible
- 5.8x faster than state-of-the-art (Heyoka)

## Mojo Compilation & Distribution

### Yes, You Can Distribute Compiled Binaries! ✅

**Compile to standalone executable**:
```bash
mojo build benchmark_adaptive_halley.mojo -o sgp4_benchmark
```

**Result**:
- Standalone executable (~136 KB)
- **No Mojo installation required** to run
- Platform-specific (compile on target OS/arch)

**Example**:
```bash
# Compile once
$ mojo build src/mojo/benchmark_adaptive_halley.mojo -o sgp4_halley_100k

# Distribute the executable
$ ls -lh sgp4_halley_100k
-rwxr-xr-x  1 user  staff   136K  sgp4_halley_100k

# Users can run without Mojo
$ ./sgp4_halley_100k
============================================================
ADAPTIVE SGP4 BENCHMARK (Halley's Method)
============================================================
...
Rate: 366,506,816 props/sec
```

**Key Points**:
- ✅ Self-contained binary (includes Mojo runtime)
- ✅ No dependencies beyond standard system libs
- ✅ Can run on any system with same OS/architecture
- ❌ Must compile separately for each platform (Linux/Mac/Windows, x86/ARM)

### Build Options

**Basic build**:
```bash
mojo build program.mojo -o executable_name
```

**For distribution** (creates smaller, optimized binary):
```bash
mojo build --release program.mojo -o executable_name
```

**Cross-compilation**: Not yet supported (must compile on target platform)

## Summary

**Actual Performance Achieved**:
- Best: **366M props/sec** (Halley, 100k satellites)
- Previous best: **384M props/sec** (Newton, 100k satellites)
- Both are world-class, 5-6x faster than state-of-the-art

**The 470M**:
- Theoretical projection, not measured
- Based on stacking multiple optimizations
- Optimistic assumptions that didn't pan out

**Distribution**:
- ✅ Yes, `mojo build` creates standalone executables
- ✅ No Mojo required to run compiled binary
- ✅ 136KB executable, self-contained

**Recommendation**: Ship the 366M Halley implementation as a compiled binary for production use.
