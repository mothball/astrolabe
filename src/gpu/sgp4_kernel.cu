// sgp4_kernel.cu - GPU-Accelerated SGP4 Kernel for NVIDIA CUDA
// Optimized for RTX 5060Ti (4608 CUDA cores, 448 GB/s bandwidth)
// Target: 10-20 billion propagations/second

#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <cmath>

// WGS72 Constants
#define KMPER 6378.135
#define KE 0.07436691613317342
#define TOTHRD 0.6666666666666666
#define CK2 0.0005413080
#define PI 3.14159265358979323846
#define TWO_PI 6.28318530717958647692
#define INV_TWO_PI 0.15915494309189533576

// Device function: Fast sin/cos using polynomial approximation
__device__ __forceinline__ void fast_sincos(double x, double* s, double* c) {
    // Cody-Waite range reduction to [-PI, PI]
    double k = floor(x * INV_TWO_PI + 0.5);
    double k_2 = k * 2.0;
    double r = __fma(-k_2, PI, x);  // FMA: x - k_2 * PI
    double r2 = r * r;
    
    // Sin polynomial (degree 5)
    double s5 = -1.9841269841269841270e-04;
    double s4 =  8.3333333333333333333e-03;
    double s3 = -1.6666666666666666667e-01;
    double sin_poly = __fma(r2, s5, s4);
    sin_poly = __fma(r2, sin_poly, s3);
    sin_poly = __fma(r2, sin_poly, 1.0);
    *s = r * sin_poly;
    
    // Cos polynomial (degree 5)
    double c5 = 2.4801587301587301587e-05;
    double c4 = -1.3888888888888888889e-03;
    double c3 =  4.1666666666666666667e-02;
    double c2 = -5.0000000000000000000e-01;
    double cos_poly = __fma(r2, c5, c4);
    cos_poly = __fma(r2, cos_poly, c3);
    cos_poly = __fma(r2, cos_poly, c2);
    *c = __fma(r2, cos_poly, 1.0);
}

// Device function: Solve Kepler's equation (Newton-Raphson, 3 iterations)
__device__ __forceinline__ double solve_kepler(double M, double e) {
    double E = M;
    #pragma unroll
    for (int i = 0; i < 3; i++) {
        double sinE, cosE;
        fast_sincos(E, &sinE, &cosE);
        double f = E - e * sinE - M;
        double f_prime = 1.0 - e * cosE;
        E = E - f / f_prime;
    }
    return E;
}

// Global kernel: Batch SGP4 propagation
__global__ void sgp4_propagate_batch_kernel(
    // Input TLE parameters (n satellites)
    const double* __restrict__ no_kozai,
    const double* __restrict__ ecco,
    const double* __restrict__ inclo,
    const double* __restrict__ nodeo,
    const double* __restrict__ argpo,
    const double* __restrict__ mo,
    const double* __restrict__ bstar,
    // Time steps (m times)
    const double* __restrict__ times,
    int num_times,
    // Output (n * m * 6)
    double* __restrict__ results,
    int num_satellites
) {
    // Thread mapping: one thread per (satellite, time) pair
    int sat_idx = blockIdx.x * blockDim.x + threadIdx.x;
    int time_idx = blockIdx.y;
    
    if (sat_idx >= num_satellites || time_idx >= num_times) return;
    
    // Load TLE parameters (coalesced access)
    double n0 = no_kozai[sat_idx];
    double e0 = ecco[sat_idx];
    double i0 = inclo[sat_idx];
    double node0 = nodeo[sat_idx];
    double omega0 = argpo[sat_idx];
    double m0 = mo[sat_idx];
    double bstar_val = bstar[sat_idx];
    double tsince = times[time_idx];
    
    // SGP4 Initialization (constants computation)
    double a1 = pow(KE / n0, TOTHRD);
    double cosi0, sini0;
    fast_sincos(i0, &sini0, &cosi0);
    double theta2 = cosi0 * cosi0;
    double x3thm1 = 3.0 * theta2 - 1.0;
    double beta02 = 1.0 - e0 * e0;
    double beta0 = sqrt(beta02);
    double dela2 = 1.5 * CK2 * x3thm1 / (beta0 * beta02);
    double del1 = dela2 / (a1 * a1);
    double a0 = a1 * (1.0 - del1 * (1.0/3.0 + del1 * (1.0 + 134.0/81.0 * del1)));
    double del0 = dela2 / (a0 * a0);
    double n0dp = n0 / (1.0 + del0);
    double a0dp = pow(KE / n0dp, TOTHRD);
    
    // Secular effects
    double perige = a0dp * (1.0 - e0) - 1.0;
    double s = 20.0 / KMPER;
    double s1_val = 78.0 / KMPER;
    if (perige - s1_val < 0.0) s = perige - s1_val;
    if (s < s1_val) s = s1_val;
    
    double s4 = 1.0 + s;
    double pinvsq = 1.0 / ((a0dp * beta02) * (a0dp * beta02));
    double xi = 1.0 / (a0dp - s4);
    double eta = a0dp * xi * e0;
    double etasq = eta * eta;
    double eeta = e0 * eta;
    double psisq = fabs(1.0 - etasq);
    double q0 = 120.0 / KMPER;
    double coef = pow((q0 - s) * xi, 4.0);
    double coef1 = coef / (sqrt(psisq) * psisq * psisq * psisq);
    
    double c1 = bstar_val * coef1 * n0dp * (
        a0dp * (1.0 + 1.5 * etasq + eeta * (4.0 + etasq))
        + 0.75 * CK2 * xi / psisq * x3thm1 * (8.0 + 3.0 * etasq * (8.0 + etasq))
    );
    
    double omgdot = -1.5 * CK2 * x3thm1 * pinvsq * n0dp;
    double xnodot = -1.5 * CK2 * cosi0 * pinvsq * n0dp;
    double xmdot = 1.5 * CK2 * x3thm1 * pinvsq * (1.0 + 3.0 * theta2) * n0dp;
    
    // Time propagation
    double omega = omega0 + omgdot * tsince;
    double xnode = node0 + xnodot * tsince;
    double xmp = m0 + xmdot * tsince;
    
    double tsq = tsince * tsince;
    double xnode_drag = xnode + xnodot * c1 * tsq;
    double xmp_drag = xmp + n0dp * ((1.5 * c1 * tsq) + (c1 * c1 * tsq * tsince));
    double omega_drag = omega - (c1 * c1 * tsq * tsq * 0.5);
    
    // Solve Kepler's equation
    double E = solve_kepler(xmp_drag, e0);
    
    // Short period effects
    double sinE, cosE;
    fast_sincos(E, &sinE, &cosE);
    double el2 = e0 * e0;
    double r = a0dp * (1.0 - e0 * cosE);
    
    double u = a0dp * (cosE - e0);
    double v = a0dp * sqrt(1.0 - el2) * sinE;
    
    double sinOMG, cosOMG, sinNODE, cosNODE;
    fast_sincos(omega_drag, &sinOMG, &cosOMG);
    fast_sincos(xnode_drag, &sinNODE, &cosNODE);
    
    // Position
    double x = u * (cosNODE * cosOMG - sinNODE * sinOMG * cosi0) 
             - v * (cosNODE * sinOMG + sinNODE * cosOMG * cosi0);
    double y = u * (sinNODE * cosOMG + cosNODE * sinOMG * cosi0) 
             + v * (sinNODE * sinOMG - cosNODE * cosOMG * cosi0);
    double z = u * sinOMG * sini0 + v * cosOMG * sini0;
    
    // Velocity
    double udot = -sqrt(a0dp) * sinE / r;
    double vdot = sqrt(a0dp * (1.0 - el2)) * cosE / r;
    
    double vx = udot * (cosNODE * cosOMG - sinNODE * sinOMG * cosi0) 
              - vdot * (cosNODE * sinOMG + sinNODE * cosOMG * cosi0);
    double vy = udot * (sinNODE * cosOMG + cosNODE * sinOMG * cosi0) 
              + vdot * (sinNODE * sinOMG - cosNODE * cosOMG * cosi0);
    double vz = udot * sinOMG * sini0 + vdot * cosOMG * sini0;
    
    // Scale to km and km/s
    x *= KMPER;
    y *= KMPER;
    z *= KMPER;
    vx *= KMPER / 60.0;
    vy *= KMPER / 60.0;
    vz *= KMPER / 60.0;
    
    // Store results (Structure of Arrays for coalesced writes)
    int base_idx = time_idx * num_satellites + sat_idx;
    results[base_idx + 0 * num_satellites * num_times] = x;
    results[base_idx + 1 * num_satellites * num_times] = y;
    results[base_idx + 2 * num_satellites * num_times] = z;
    results[base_idx + 3 * num_satellites * num_times] = vx;
    results[base_idx + 4 * num_satellites * num_times] = vy;
    results[base_idx + 5 * num_satellites * num_times] = vz;
}

// Host function to launch kernel
extern "C" {
    void sgp4_propagate_gpu(
        const double* no_kozai, const double* ecco, const double* inclo,
        const double* nodeo, const double* argpo, const double* mo,
        const double* bstar, const double* times, int num_times,
        double* results, int num_satellites
    ) {
        // Kernel launch configuration
        int threads_per_block = 256;
        dim3 block(threads_per_block);
        dim3 grid((num_satellites + threads_per_block - 1) / threads_per_block, num_times);
        
        sgp4_propagate_batch_kernel<<<grid, block>>>(
            no_kozai, ecco, inclo, nodeo, argpo, mo, bstar,
            times, num_times, results, num_satellites
        );
        
        cudaDeviceSynchronize();
    }
}
