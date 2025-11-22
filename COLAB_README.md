# Google Colab SGP4 GPU Testing

Quick guide to test Astrolabe SGP4 on Google Colab's free T4 GPU.

## 🚀 Quick Start

1. **Open in Colab:**
   - Upload `SGP4_GPU_Colab.ipynb` to Google Drive
   - Open with Google Colab
   - Or: File → Upload notebook in Colab

2. **Enable GPU:**
   - Runtime → Change runtime type
   - Hardware accelerator → **T4 GPU**
   - Save

3. **Run:**
   - Runtime → Run all
   - Wait ~2-3 minutes for Mojo installation
   - Check results!

## 📊 Expected Results

| Hardware | Performance | Notes |
|----------|-------------|-------|
| T4 GPU | 2-5 billion props/sec | Free tier ✅ |
| Colab CPU | ~50-100M props/sec | Fallback |

## 🔧 What the Notebook Does

1. ✅ Installs Mojo/MAX
2. ✅ Checks GPU availability  
3. ✅ Creates GPU kernel (simplified SGP4)
4. ✅ Runs performance benchmark
5. ✅ Compares to CPU baseline

## ⚠️ Limitations

- **Simplified kernel:** Full SGP4 code too large for Colab cells
- **Free tier:** 12-hour sessions, may disconnect
- **GPU quota:** Limited weekly GPU hours

## 🐛 Troubleshooting

### "No GPU detected"
- Check Runtime → Change runtime type → T4 GPU
- Restart runtime
- GPU quota may be exhausted (try later)

### "Mojo not found"
- Re-run Cell 1 (pip install)
- Restart runtime
- Check Mojo version compatibility

### "CUDA error"
- Normal - Mojo doesn't need CUDA toolkit
- Should still work via DeviceContext

## 🎯 Full Implementation

For complete SGP4 code:
- **GitHub:** https://github.com/yourusername/astrolabe
- **Local benchmarks:** See `OPTIMIZATIONS.md`

## 💡 Tips

- **Increase batch size** for better GPU utilization (memory permitting)
- **Save results** before session expires
- **Compare** with CPU implementation to see GPU speedup

---

**Built with ❤️ using Mojo**
