---
sidebar_position: 3
---

# Hardware Guide

Understanding GPU requirements and optimizing for your hardware.

## Why VRAM Matters

Large Language Models (LLMs) load their weights into GPU memory. More VRAM = larger models = better intelligence.

### VRAM vs Model Size

| Model Parameters | FP16 VRAM | Q8 VRAM | Q4 VRAM |
|------------------|-----------|---------|---------|
| 7B | 14GB | 8GB | 4GB |
| 13B | 26GB | 14GB | 7GB |
| 32B | 64GB | 34GB | 18GB |
| 70B | 140GB | 75GB | 40GB |

**Quantization explained:**
- **FP16** - Full precision, best quality
- **Q8** - 8-bit quantization, ~95% quality
- **Q4** - 4-bit quantization, ~90% quality

:::tip Rule of Thumb
For Q4 quantization: `VRAM needed ≈ Parameters (B) × 0.6`

Example: 32B model needs ~19GB VRAM at Q4.
:::

## GPU Recommendations

### Budget: RTX 3060 (12GB) - ~$300

**Best for:** Learning, small models, quick experiments

**Can run:**
- 7B models at Q8 (llama3.1:8b, mistral:7b)
- 13B models at Q4 (qwen3:14b-q4)

**Cannot run:**
- 32B+ models (insufficient VRAM)

### Mid-Range: RTX 4090 (24GB) - ~$1,600

**Best for:** Serious local AI work, coding assistants

**Can run:**
- 7-13B models at FP16
- 32B models at Q4-Q6 (qwen3:32b, deepseek-r1:32b)
- 70B models at Q2-Q3 (usable but degraded)

**Sweet spot:** 32B models with excellent quality.

### High-End: RTX 5090 (32GB) - ~$2,000

**Best for:** Professional use, maximum model quality

**Can run:**
- 32B models at Q8 (near-full quality)
- 70B models at Q4 (llama3.3:70b-instruct-q4_K_M)
- Multiple models loaded simultaneously

**Why 32GB matters:** The jump from 24GB to 32GB unlocks 70B models and allows running multiple smaller models concurrently.

## Tested Configurations

### Configuration 1: RTX 5090 (32GB)

| Model | Quantization | Load Time | Tokens/sec |
|-------|--------------|-----------|------------|
| qwen3:32b | Q8 | 3.2s | 45 |
| deepseek-r1:32b | Q8 | 3.5s | 42 |
| llama3.3:70b | Q4_K_M | 8.1s | 28 |

### Configuration 2: RTX 4090 (24GB)

| Model | Quantization | Load Time | Tokens/sec |
|-------|--------------|-----------|------------|
| qwen3:32b | Q4_K_M | 2.8s | 52 |
| llama3.1:8b | Q8 | 0.9s | 95 |
| mistral:7b | Q8 | 0.8s | 105 |

## Multi-GPU Setups

Ollama supports splitting models across multiple GPUs:

```powershell
# Automatic layer distribution
$env:OLLAMA_NUM_GPU = 2
ollama serve
```

:::warning Diminishing Returns
Multi-GPU adds PCIe transfer overhead. Two RTX 4090s are often slower than one RTX 5090 for single-model inference.
:::

## CPU Offloading

When VRAM is insufficient, layers can offload to system RAM:

```powershell
# Allow 10 layers on CPU
$env:OLLAMA_NUM_CPU_LAYERS = 10
```

**Trade-off:** CPU layers are 10-50x slower than GPU layers. Use this only when you must run a specific model.

## Storage Considerations

### Model Storage

Models are stored in `~/.ollama/models/`. Typical sizes:

| Model | Disk Space |
|-------|------------|
| 7B Q4 | 4GB |
| 13B Q4 | 8GB |
| 32B Q4 | 18GB |
| 70B Q4 | 40GB |

**Recommendation:** Use NVMe SSD for model storage. Load times are 2-3x faster than SATA SSD.

### Moving Model Storage

```powershell
# Move to different drive
$env:OLLAMA_MODELS = "D:\ollama-models"
[Environment]::SetEnvironmentVariable("OLLAMA_MODELS", "D:\ollama-models", "User")
```

## Performance Optimization

### Flash Attention

Enabled by default in Ollama. Reduces VRAM usage and improves speed for long contexts.

### Context Window

Larger context = more VRAM. Default is typically 2048-4096 tokens.

```powershell
# Increase context (uses more VRAM)
ollama run qwen3:32b --context 8192
```

### Batch Size

For API-heavy workloads:

```powershell
$env:OLLAMA_MAX_LOADED_MODELS = 3
$env:OLLAMA_NUM_PARALLEL = 4
```

## Cooling and Power

### Power Requirements

| GPU | TDP | PSU Recommendation |
|-----|-----|-------------------|
| RTX 3060 | 170W | 550W+ |
| RTX 4090 | 450W | 850W+ |
| RTX 5090 | 575W | 1000W+ |

### Thermal Throttling

LLM inference is sustained load. Monitor temperatures:

```powershell
# Real-time GPU stats
nvidia-smi -l 1
```

**Target:** Keep GPU under 80°C for consistent performance. Consider aftermarket cooling for sustained workloads.
