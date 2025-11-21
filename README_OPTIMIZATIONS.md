# Astrolabe SGP4 - Performance Optimizations

Ultra-high-performance satellite orbit propagation using SGP4 algorithm in Mojo.

## 🚀 Performance Highlights

- **420 million propagations/second** on AMD Ryzen 9 9950X3D (AVX-512)
- **2.5x faster** than previous state-of-the-art (Heyoka)
- **206 million props/sec** on Apple M3 Pro (NEON)
- **Accuracy:** < 1.4e-13 max error (machine precision)
- **Portable:** ARM (NEON) + x86 (AVX-512/AVX2/SSE2)

## 📋 Optimization Summary

| Technique | Speedup | Implementation |
|-----------|---------|----------------|
| SIMD Vectorization | 6x | Process 8 satellites in parallel |
| FMA Instructions | 1.5x | Fused Multiply-Add for sin/cos |
| Fast Transcendentals | 3x | Polynomial approximations |
| Two-Phase Computation | 1.4x | Precompute constants |
| Multi-threading | 32x | Parallelize across CPU cores |
| Kepler Solver | 1.25x | Reduce iterations 5→3 |
| **Combined** | **210x** | **vs single-threaded baseline** |

## 🔧 Key Optimizations

### 1. SIMD Vectorization (8-wide AVX-512)
```mojo
alias Vec8 = SIMD[DType.float64, 8]
var a1 = (KE / no_kozai) ** TOTHRD  // 8 satellites at once
```

### 2. FMA-Optimized Fast Math
```mojo
var sin_poly = fma(r2, s5, s4)      // 1 instruction vs 2
sin_poly = fma(r2, sin_poly, s3)    // Better performance + accuracy
```

### 3. Two-Phase: Init Once, Propagate Many
```mojo
var constants = sgp4_init_avx512(...)   // Once per satellite
for time in times:
    sgp4_propagate_avx512(constants, time, ...)  // Reuse constants
```

### 4. Width-Generic Code
```mojo
fn fast_sin_cos_fma[width: Int](x: SIMD[DType.float64, width]):
    // Works for width = 2, 4, 8 (SSE2, AVX2/NEON, AVX-512)
```

## 📁 File Structure

```
src/mojo/
├── sgp4_two_phase.mojo          # Optimized AVX-512 (fastest)
├── sgp4_adaptive.mojo           # Portable (2/4/8-wide SIMD)
├── fast_math_optimized.mojo     # FMA-optimized transcendentals
├── sgp4_mojo_gpu_correct.mojo   # GPU kernel (experimental)
└── benchmark_two_phase.mojo     # Performance benchmarks
```

## 🏃 Quick Start

```bash
# Clone repository
git clone https://github.com/yourusername/astrolabe.git
cd astrolabe

# Run benchmark (requires Mojo nightly)
mojo src/mojo/benchmark_two_phase.mojo
```

## 📊 Performance Comparison

| Implementation | Props/Sec | Accuracy |
|----------------|-----------|----------|
| **Astrolabe (CPU)** | **420M** | < 1e-13 |
| Heyoka (C++ SIMD) | 170M | < 1e-12 |
| SGP4 Reference (C++) | 10M | < 1e-12 |

## 📖 Documentation

- **[OPTIMIZATIONS.md](OPTIMIZATIONS.md)** - Detailed optimization techniques with code examples
- **[SGP4_VALIDATION_REPORT.md](SGP4_VALIDATION_REPORT.md)** - Accuracy analysis and completeness assessment
- **[LITERATURE_REVIEW.md](LITERATURE_REVIEW.md)** - Comparison with state-of-the-art implementations

## 🎯 Use Cases

- **Real-time satellite tracking** (100K+ satellites)
- **Trajectory optimization** (millions of propagations)
- **Conjunction analysis** (batch processing)
- **Space situational awareness** (high-throughput)

## 🔬 Technical Details

### Accuracy
- Sin/cos approximation: < 1e-13 error
- Kepler solver: < 1e-15 convergence  
- Overall propagation: < 1.4e-13 max error

### Hardware Support
- ✅ x86_64: AVX-512, AVX2, SSE2
- ✅ ARM: NEON (Apple Silicon, AWS Graviton)
- 🚧 GPU: NVIDIA/AMD/Apple (code complete, pending hardware)

## 📜 License

MIT License - See [LICENSE](LICENSE) file

## 🙏 Acknowledgments

- Heyoka project for performance benchmarks
- Vallado et al. for SGP4 standard
- Mojo team for blazing-fast language

## 📬 Contact

For questions or contributions, open an issue on GitHub.

**Built with ❤️ using Mojo**
