# SGP4 Benchmark Comparison Instructions

These scripts are designed to compare the performance of the Mojo AVX-512 SGP4 implementation against the Heyoka Python library on your remote server (Ryzen 9 9950X3D).

## Prerequisites

1.  **Mojo** installed and in the path (or in `./venv/bin/mojo`).
2.  **Heyoka** installed in the Python environment (`./venv/bin/python`).
3.  **AVX-512** support (Ryzen 7000/9000 series or Intel Skylake-X/Ice Lake/etc.).

## Files

*   `benchmark_comparison.py`: Main script to run both benchmarks and compare results.
*   `benchmark_heyoka.py`: Python script to benchmark Heyoka.
*   `src/mojo/benchmark_avx512.mojo`: Mojo script to benchmark AVX-512 implementation.

## How to Run

1.  Ensure all files are on the remote server.
2.  Activate your virtual environment:
    ```bash
    source venv/bin/activate
    ```
3.  Run the comparison script:
    ```bash
    python benchmark_comparison.py
    ```

## Troubleshooting

*   **Heyoka not found**: Ensure `heyoka` is installed in the active environment. Try `pip list | grep heyoka`.
*   **Mojo crash**: If Mojo crashes, ensure your CPU supports AVX-512. If running on a machine without AVX-512 (e.g., laptop), use `benchmark_simd.mojo` instead.
*   **Paths**: The script assumes `./venv/bin/mojo` and `./venv/bin/python`. If your paths differ, edit `benchmark_comparison.py`.
