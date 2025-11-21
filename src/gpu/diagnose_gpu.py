#!/usr/bin/env python3
"""
Diagnostic script for GPU CUDA setup
"""

import sys

def check_import(module_name):
    try:
        __import__(module_name)
        print(f"✓ {module_name} imported successfully")
        return True
    except ImportError as e:
        print(f"✗ {module_name} import failed: {e}")
        return False

def main():
    print("=" * 70)
    print("CUDA ENVIRONMENT DIAGNOSTIC")
    print("=" * 70)
    
    # Check imports
    print("\n1. Checking Python modules...")
    numpy_ok = check_import("numpy")
    cupy_ok = check_import("cupy")
    
    if not cupy_ok:
        print("\nCuPy not available. Exiting.")
        return
    
    # Check CuPy CUDA availability
    print("\n2. Checking CuPy CUDA detection...")
    import cupy as cp
    try:
        print(f"  CuPy version: {cp.__version__}")
        print(f"  CUDA available: {cp.cuda.is_available()}")
        
        if cp.cuda.is_available():
            print(f"  CUDA version: {cp.cuda.runtime.runtimeGetVersion()}")
            device_count = cp.cuda.runtime.getDeviceCount()
            print(f"  Device count: {device_count}")
            
            if device_count > 0:
                print("\n3. Device information:")
                for i in range(device_count):
                    device = cp.cuda.Device(i)
                    print(f"\n  Device {i}:")
                    print(f"    Name: {device.name}")
                    print(f"    Compute Capability: {device.compute_capability}")
                    print(f"    Total Memory: {device.mem_info[1] / 1024**3:.2f} GB")
            else:
                print("\n✗ No CUDA devices found!")
        else:
            print("\n✗ CUDA not available to CuPy!")
            
    except Exception as e:
        print(f"\n✗ Error checking CUDA: {e}")
        import traceback
        traceback.print_exc()
    
    # Test simple GPU operation
    print("\n4. Testing simple GPU operation...")
    try:
        x = cp.array([1, 2, 3])
        y = cp.array([4, 5, 6])
        z = x + y
        print(f"  ✓ Simple GPU computation works: {z}")
    except Exception as e:
        print(f"  ✗ GPU computation failed: {e}")

if __name__ == "__main__":
    main()
