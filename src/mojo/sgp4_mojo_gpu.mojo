from memory import UnsafePointer
from builtin.simd import SIMD
from builtin.dtype import DType  
from math import fma, floor, sqrt, abs

# WGS72 Constants
alias KMPER: Float64 = 6378.135
alias KE: Float64 = 0.07436691613317342
alias TOTHRD: Float64 = 2.0 / 3.0
alias CK2: Float64 = 0.0005413080
alias PI: Float64 = 3.14159265358979323846
alias TWO_PI: Float64 = 6.28318530717958647692
alias INV_TWO_PI: Float64 = 0.15915494309189533576

# GPU Kernel using Mojo's @gpu.kernel decorator
@gpu.kernel
fn sgp4_gpu_kernel(
    no_kozai: UnsafePointer[Float64],
    ecco: UnsafePointer[Float64],
    inclo: UnsafePointer[Float64],
    nodeo: UnsafePointer[Float64],
    argpo: UnsafePointer[Float64],
    mo: UnsafePointer[Float64],
    bstar: UnsafePointer[Float64],
    times: UnsafePointer[Float64],
    num_times: Int,
    results: UnsafePointer[Float64],
    num_satellites: Int
):
    """
    GPU kernel for SGP4 batch propagation.
    One thread per (satellite, time) pair.
    Works on NVIDIA, AMD, and Apple GPUs without CUDA.
    """
    
    # GPU thread indexing
    var sat_idx = gpu.thread_id(0) + gpu.block_id(0) * gpu.block_dim(0)
    var time_idx = gpu.thread_id(1) + gpu.block_id(1) * gpu.block_dim(1)
    
    if sat_idx >= num_satellites or time_idx >= num_times:
        return
    
    # Load TLE parameters
    var n0 = no_kozai[sat_idx]
    var e0 = ecco[sat_idx]
    var i0 = inclo[sat_idx]
    var node0 = nodeo[sat_idx]
    var omega0 = argpo[sat_idx]
    var m0 = mo[sat_idx]
    var bstar_val = bstar[sat_idx]
    var tsince = times[time_idx]
    
    # Fast sin/cos using polynomial approximation (FMA optimized)
    fn fast_sincos(x: Float64) -> Tuple[Float64, Float64]:
        # Range reduction
        var k = floor(x * INV_TWO_PI + 0.5)
        var k_2 = k * 2.0
        var r = fma(-k_2, PI, x)
        var r2 = r * r
        
        # Sin polynomial (deg 5)
        var s5 = -1.9841269841269841270e-04
        var s4 =  8.3333333333333333333e-03
        var s3 = -1.6666666666666666667e-01
        var sin_val = fma(r2, s5, s4)
        sin_val = fma(r2, sin_val, s3)
        sin_val = fma(r2, sin_val, 1.0)
        sin_val = r * sin_val
        
        # Cos polynomial (deg 5)
        var c5 = 2.4801587301587301587e-05
        var c4 = -1.3888888888888888889e-03
        var c3 =  4.1666666666666666667e-02
        var c2 = -5.0000000000000000000e-01
        var cos_val = fma(r2, c5, c4)
        cos_val = fma(r2, cos_val, c3)
        cos_val = fma(r2, cos_val, c2)
        cos_val = fma(r2, cos_val, 1.0)
        
        return (sin_val, cos_val)
    
    # SGP4 Initialization
    var a1 = pow(KE / n0, TOTHRD)
    var sc_i0 = fast_sincos(i0)
    var sini0 = sc_i0[0]
    var cosi0 = sc_i0[1]
    var theta2 = cosi0 * cosi0
    var x3thm1 = 3.0 * theta2 - 1.0
    var beta02 = 1.0 - e0 * e0
    var beta0 = sqrt(beta02)
    var dela2 = 1.5 * CK2 * x3thm1 / (beta0 * beta02)
    var del1 = dela2 / (a1 * a1)
    var a0 = a1 * (1.0 - del1 * (1.0/3.0 + del1 * (1.0 + 134.0/81.0 * del1)))
    var del0 = dela2 / (a0 * a0)
    var n0dp = n0 / (1.0 + del0)
    var a0dp = pow(KE / n0dp, TOTHRD)
    
    # Secular effects
    var perige = a0dp * (1.0 - e0) - 1.0
    var s = 20.0 / KMPER
    var s1_val = 78.0 / KMPER
    if perige - s1_val < 0.0:
        s = perige - s1_val
    if s < s1_val:
        s = s1_val
    
    var s4 = 1.0 + s
    var pinvsq = 1.0 / ((a0dp * beta02) * (a0dp * beta02))
    var xi = 1.0 / (a0dp - s4)
    var eta = a0dp * xi * e0
    var etasq = eta * eta
    var eeta = e0 * eta
    var psisq = abs(1.0 - etasq)
    var q0 = 120.0 / KMPER
    var coef = pow((q0 - s) * xi, 4.0)
    var coef1 = coef / (sqrt(psisq) * psisq * psisq * psisq)
    
    var c1 = bstar_val * coef1 * n0dp * (
        a0dp * (1.0 + 1.5 * etasq + eeta * (4.0 + etasq))
        + 0.75 * CK2 * xi / psisq * x3thm1 * (8.0 + 3.0 * etasq * (8.0 + etasq))
    )
    
    var omgdot = -1.5 * CK2 * x3thm1 * pinvsq * n0dp
    var xnodot = -1.5 * CK2 * cosi0 * pinvsq * n0dp
    var xmdot = 1.5 * CK2 * x3thm1 * pinvsq * (1.0 + 3.0 * theta2) * n0dp
    
    # Time propagation
    var omega = omega0 + omgdot * tsince
    var xnode = node0 + xnodot * tsince
    var xmp = m0 + xmdot * tsince
    
    var tsq = tsince * tsince
    var xnode_drag = xnode + xnodot * c1 * tsq
    var xmp_drag = xmp + n0dp * ((1.5 * c1 * tsq) + (c1 * c1 * tsq * tsince))
    var omega_drag = omega - (c1 * c1 * tsq * tsq * 0.5)
    
    # Solve Kepler's equation (3 Newton-Raphson iterations)
    var E = xmp_drag
    for _ in range(3):
        var sc_E = fast_sincos(E)
        var sinE = sc_E[0]
        var cosE = sc_E[1]
        E = E - (E - e0 * sinE - xmp_drag) / (1.0 - e0 * cosE)
    
    # Short period effects
    var sc_E = fast_sincos(E)
    var sinE = sc_E[0]
    var cosE = sc_E[1]
    var el2 = e0 * e0
    var r = a0dp * (1.0 - e0 * cosE)
    
    var u = a0dp * (cosE - e0)
    var v = a0dp * sqrt(1.0 - el2) * sinE
    
    var sc_omg = fast_sincos(omega_drag)
    var sinOMG = sc_omg[0]
    var cosOMG = sc_omg[1]
    var sc_node = fast_sincos(xnode_drag)
    var sinNODE = sc_node[0]
    var cosNODE = sc_node[1]
    
    # Position
    var x = u * (cosNODE * cosOMG - sinNODE * sinOMG * cosi0) - v * (cosNODE * sinOMG + sinNODE * cosOMG * cosi0)
    var y = u * (sinNODE * cosOMG + cosNODE * sinOMG * cosi0) + v * (sinNODE * sinOMG - cosNODE * cosOMG * cosi0)
    var z = u * sinOMG * sini0 + v * cosOMG * sini0
    
    # Velocity
    var udot = -sqrt(a0dp) * sinE / r
    var vdot = sqrt(a0dp * (1.0 - el2)) * cosE / r
    
    var vx = udot * (cosNODE * cosOMG - sinNODE * sinOMG * cosi0) - vdot * (cosNODE * sinOMG + sinNODE * cosOMG * cosi0)
    var vy = udot * (sinNODE * cosOMG + cosNODE * sinOMG * cosi0) + vdot * (sinNODE * sinOMG - cosNODE * cosOMG * cosi0)
    var vz = udot * sinOMG * sini0 + vdot * cosOMG * sini0
    
    # Scale to km and km/s
    x = x * KMPER
    y = y * KMPER
    z = z * KMPER
    vx = vx * KMPER / 60.0
    vy = vy * KMPER / 60.0
    vz = vz * KMPER / 60.0
    
    # Write to global memory (coalesced)
    var base_idx = time_idx * num_satellites + sat_idx
    results[base_idx + 0 * num_satellites * num_times] = x
    results[base_idx + 1 * num_satellites * num_times] = y
    results[base_idx + 2 * num_satellites * num_times] = z
    results[base_idx + 3 * num_satellites * num_times] = vx
    results[base_idx + 4 * num_satellites * num_times] = vy
    results[base_idx + 5 * num_satellites * num_times] = vz

fn propagate_batch_gpu(
    no_kozai: UnsafePointer[Float64],
    ecco: UnsafePointer[Float64],
    inclo: UnsafePointer[Float64],
    nodeo: UnsafePointer[Float64],
    argpo: UnsafePointer[Float64],
    mo: UnsafePointer[Float64],
    bstar: UnsafePointer[Float64],
    times: UnsafePointer[Float64],
    num_times: Int,
    results: UnsafePointer[Float64],
    num_satellites: Int
) raises:
    """
    Launch GPU kernel for batch propagation.
    Automatically uses available GPU (NVIDIA/AMD/Apple).
    """
    
    # Configure grid and block dimensions
    var threads_per_block_x = 16
    var threads_per_block_y = 16
    var grid_x = (num_satellites + threads_per_block_x - 1) // threads_per_block_x
    var grid_y = (num_times + threads_per_block_y - 1) // threads_per_block_y
    
    # Launch kernel
    gpu.launch[sgp4_gpu_kernel](
        grid=(grid_x, grid_y),
        block=(threads_per_block_x, threads_per_block_y),
        args=(no_kozai, ecco, inclo, nodeo, argpo, mo, bstar,
              times, num_times, results, num_satellites)
    )
    
    # Synchronize
    gpu.synchronize()

fn main() raises:
    print("Mojo Native GPU SGP4")
    print("Works on NVIDIA, AMD, and Apple GPUs")
    print("No CUDA required!")
