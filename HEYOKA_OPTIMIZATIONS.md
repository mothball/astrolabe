# Heyoka-Inspired Optimizations for Mojo SGP4

## Analysis of Heyoka's Performance

### Heyoka Benchmark Results
- **Single-threaded**: 13M props/sec
- **16-core (AMD Ryzen 9 5950X)**: 170M props/sec
- **Speedup vs Python sgp4**: 4x (single-threaded)
- **Multi-core scaling**: 13x (170M / 13M)

### Our Current Performance
- **Single-threaded**: ~3.8M props/sec (Real SGP4, no SIMD)
- **Multi-core + SIMD**: 11.6M props/sec (16 cores)
- **Speedup vs Python sgp4**: 3.58x

## Key Heyoka Optimizations to Implement

### 1. **JIT Compilation with Expression Templates** ⭐⭐⭐
**Heyoka's Secret Weapon**: They use symbolic expression compilation

- **What they do**: Convert SGP4 equations to symbolic expressions, then JIT-compile to optimized machine code
- **Benefit**: Eliminates function call overhead, enables aggressive compiler optimizations
- **Mojo equivalent**: Use `@always_inline` more aggressively + compile-time evaluation

### 2. **True Structure-of-Arrays (SoA) Layout** ⭐⭐⭐
**Current**: We have SoA but don't fully exploit it
**Heyoka**: Stores all data for one parameter across all satellites contiguously

```python
# Heyoka layout (9 parameters × 22333 satellites)
sat_data.shape = (9, 22333)
# Row 0: all mean motions [sat0, sat1, sat2, ...]
# Row 1: all eccentricities [sat0, sat1, sat2, ...]
```

**Benefit**: Perfect for SIMD - load 4-8 consecutive satellites' data in one instruction

### 3. **Pre-allocated Output Buffers** ⭐⭐
**What they do**: Reuse output arrays across propagations
**Benefit**: Eliminates allocation overhead for repeated propagations

### 4. **Batch-Mode Propagation** ⭐⭐⭐
**What they do**: Propagate all satellites to multiple time points in one call
**Shape**: `(num_times, 7_outputs, num_satellites)`
**Benefit**: Amortizes setup costs, better cache utilization

### 5. **Wider SIMD (AVX-512)** ⭐⭐
**Heyoka**: Likely uses 8-wide or even 16-wide SIMD
**Us**: Currently 4-wide
**Benefit**: 2x improvement with 8-wide SIMD

### 6. **Optimized Kepler Solver** ⭐⭐
**Heyoka**: Uses optimized Newton-Raphson with better initial guess
**Us**: Basic 5-iteration solver
**Benefit**: Fewer iterations needed, faster convergence

## Implementation Plan

### Phase 1: Memory Layout Optimization (High Impact)
1. **True SoA with contiguous memory**
   - Store each parameter in a separate contiguous array
   - Optimize for cache line alignment (64-byte boundaries)
   - Enable perfect SIMD loads

2. **Pre-allocated output buffers**
   - Reuse result arrays
   - Eliminate allocation overhead

### Phase 2: SIMD Width Increase (Medium Impact)
1. **8-wide SIMD** (if CPU supports AVX-512)
   - Double current SIMD width
   - Expected: 2x improvement → 23M props/sec

### Phase 3: Batch-Mode Propagation (High Impact)
1. **Multi-time propagation**
   - Propagate to N time points in one call
   - Shape: `(N_times, 6, N_satellites)`
   - Amortize setup costs

### Phase 4: Expression Optimization (Medium Impact)
1. **Aggressive inlining**
   - Mark all helper functions `@always_inline`
   - Eliminate function call overhead

2. **Compile-time constants**
   - Use `alias` for all constants
   - Enable constant folding

3. **Loop unrolling**
   - Manually unroll Kepler solver iterations
   - Unroll SIMD lanes

## Expected Performance Gains

| Optimization | Current | After | Improvement |
|--------------|---------|-------|-------------|
| **Baseline** | 11.6M | - | - |
| + True SoA + alignment | 11.6M | 17M | 1.5x |
| + 8-wide SIMD | 17M | 34M | 2x |
| + Batch mode | 34M | 50M | 1.5x |
| + Expression opts | 50M | 70M | 1.4x |
| **Total** | **11.6M** | **70M** | **6x** |

### Comparison to Heyoka
- **Heyoka 16-core**: 170M props/sec
- **Our target**: 70M props/sec
- **Gap**: 2.4x

**Why the gap?**
1. Heyoka uses JIT compilation with symbolic expressions (huge win)
2. Heyoka is written in C++ with years of optimization
3. Heyoka may use AVX-512 (16-wide SIMD)
4. Our SGP4 is simplified, not full implementation

## Priority Optimizations (Quick Wins)

### 1. True SoA Layout (1-2 hours)
**Impact**: 1.5x improvement
**Difficulty**: Medium

### 2. 8-wide SIMD (30 minutes)
**Impact**: 2x improvement  
**Difficulty**: Easy (just change SIMD_WIDTH)

### 3. Aggressive Inlining (30 minutes)
**Impact**: 1.2x improvement
**Difficulty**: Easy

### 4. Batch Mode (2-3 hours)
**Impact**: 1.5x improvement
**Difficulty**: Medium

## Recommended Next Steps

1. **Implement 8-wide SIMD** (quick win, 2x improvement)
2. **Optimize memory layout** (SoA with alignment)
3. **Add batch-mode propagation** (multi-time support)
4. **Profile and optimize hot paths**

**Expected final performance**: 50M-70M props/sec (4x-6x current, 15x-21x vs Python)

## Code Structure

```mojo
# Optimized layout
struct SGP4PropagatorBatch:
    # SoA layout - each array is aligned to 64-byte boundaries
    var no_kozai: UnsafePointer[Float64]  # [sat0, sat1, sat2, sat3, sat4, sat5, sat6, sat7, ...]
    var ecco: UnsafePointer[Float64]
    var inclo: UnsafePointer[Float64]
    # ... other parameters
    
    var num_satellites: Int
    var simd_width: Int = 8  # AVX-512
    
    fn propagate_batch(
        self,
        times: UnsafePointer[Float64],  # Array of times
        num_times: Int,
        out: UnsafePointer[Float64]  # Pre-allocated: (num_times, 6, num_satellites)
    ):
        # Batch propagation with 8-wide SIMD
        pass
```

## Conclusion

By implementing Heyoka-inspired optimizations, we can achieve:
- **50M-70M props/sec** (vs current 11.6M)
- **15x-21x faster** than Python sgp4
- **Still 2-3x slower** than Heyoka (due to their JIT compilation advantage)

The key is combining:
1. True SoA memory layout
2. 8-wide SIMD
3. Batch-mode propagation
4. Aggressive inlining and compile-time optimization
