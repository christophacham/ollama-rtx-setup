---
sidebar_position: 4
---

# Performance Tuning

Optimize Ollama for your hardware and workload.

## Understanding Performance Metrics

### Tokens Per Second (TPS)

The primary measure of inference speed:
- **Prompt processing** - How fast input is processed
- **Generation** - How fast output is produced

```powershell
# Benchmark a model
ollama run qwen3:32b "Write a 500-word essay about AI" --verbose
# Look for: eval rate: XX tokens/s
```

### Typical Performance

| Model | RTX 4090 | RTX 5090 |
|-------|----------|----------|
| 7B Q4 | 120 t/s | 150 t/s |
| 32B Q4 | 45 t/s | 60 t/s |
| 70B Q4 | 15 t/s | 28 t/s |

## Environment Variables

### Essential Settings

```powershell
# Number of GPU layers (default: all that fit)
$env:OLLAMA_NUM_GPU = 99

# Maximum loaded models (memory permitting)
$env:OLLAMA_MAX_LOADED_MODELS = 3

# Parallel request handling
$env:OLLAMA_NUM_PARALLEL = 4

# Keep models loaded (default: 5m)
$env:OLLAMA_KEEP_ALIVE = "30m"
```

### Memory Management

```powershell
# CPU layers for overflow (slower, but allows larger models)
$env:OLLAMA_NUM_CPU = 4

# Flash attention (enabled by default)
$env:OLLAMA_FLASH_ATTENTION = 1
```

### Persistence

Set variables permanently:

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "30m", "User")
```

## Context Window Optimization

### What is Context?

Context window = how much text the model can "see" at once. Larger context:
- Allows longer conversations
- Uses more VRAM
- Slightly slower inference

### Default Context

| Model | Default Context | Max Context |
|-------|-----------------|-------------|
| llama3.1 | 4096 | 131072 |
| qwen3 | 4096 | 32768 |
| mistral | 4096 | 32768 |

### Adjusting Context

```powershell
# Increase for long documents
ollama run qwen3:32b --num-ctx 16384

# Reduce for faster response
ollama run qwen3:32b --num-ctx 2048
```

### VRAM Impact

| Context | Additional VRAM |
|---------|-----------------|
| 4096 | Base |
| 8192 | +500MB |
| 16384 | +1.5GB |
| 32768 | +4GB |

## Batch Processing

### Concurrent Requests

For API-heavy workloads:

```powershell
# Allow 4 parallel requests
$env:OLLAMA_NUM_PARALLEL = 4

# Each request gets its own context
# VRAM usage multiplies!
```

### Batch Size Tuning

```powershell
# Larger batches = faster throughput, more VRAM
$env:OLLAMA_BATCH_SIZE = 512  # Default varies by model
```

## Model Loading

### Keep Alive Settings

```powershell
# Never unload (fast responses, uses VRAM)
$env:OLLAMA_KEEP_ALIVE = -1

# Unload after 5 minutes (default)
$env:OLLAMA_KEEP_ALIVE = "5m"

# Unload immediately (saves VRAM)
$env:OLLAMA_KEEP_ALIVE = 0
```

### Preloading Models

```powershell
# Load model at startup
ollama run qwen3:32b ""  # Empty prompt just loads

# Or via API
curl http://localhost:11434/api/generate -d '{"model":"qwen3:32b"}'
```

### LRU Eviction

When VRAM fills, least-recently-used models are unloaded:

```
Model A loaded → Model B loaded → Model C loaded
                                  ↓ (VRAM full)
Model A unloaded (LRU) ← Model C used
```

## Quantization Trade-offs

### Quality vs Speed

| Quantization | Quality | Speed | VRAM |
|--------------|---------|-------|------|
| Q8_0 | 99% | Slower | More |
| Q6_K | 97% | Medium | Medium |
| Q4_K_M | 95% | Fast | Less |
| Q4_0 | 92% | Fastest | Least |

### When to Use Each

- **Q8**: When quality is critical (coding, reasoning)
- **Q4_K_M**: General use (best balance)
- **Q4_0**: Speed priority, acceptable quality loss

## GPU-Specific Optimization

### NVIDIA Settings

```powershell
# Check current GPU state
nvidia-smi

# Lock GPU clocks for consistent performance
nvidia-smi -pm 1  # Persistence mode
nvidia-smi -lgc 2100  # Lock graphics clock
```

### Power Management

| Mode | Performance | Power |
|------|-------------|-------|
| Maximum | 100% | 100% |
| Balanced | 95% | 80% |
| Power Saver | 70% | 50% |

```powershell
# Set maximum performance
nvidia-smi -pl 575  # Set power limit (watts)
```

## Monitoring Performance

### Real-time GPU Stats

```powershell
# Live monitoring
nvidia-smi -l 1

# Or more detailed
nvidia-smi dmon -s pucvmet
```

### Ollama Metrics

```powershell
# Check loaded models
ollama ps

# Model info including parameters
ollama show qwen3:32b
```

### Benchmark Script

```powershell
# Simple benchmark
$prompt = "Write a detailed explanation of quantum computing in 500 words."
$models = @("llama3.1:8b", "qwen3:32b")

foreach ($model in $models) {
    $start = Get-Date
    ollama run $model $prompt | Out-Null
    $duration = (Get-Date) - $start
    Write-Host "$model : $($duration.TotalSeconds)s"
}
```

## Common Performance Issues

### Slow First Response

**Cause:** Model loading from disk.

**Fix:** Increase keep-alive or preload:
```powershell
$env:OLLAMA_KEEP_ALIVE = "1h"
```

### Degrading Performance Over Time

**Cause:** Thermal throttling.

**Fix:** Improve cooling or reduce power limit:
```powershell
nvidia-smi -pl 500  # Reduce from 575W to 500W
```

### Out of Memory Errors

**Cause:** Too many models or too large context.

**Fix:**
```powershell
# Reduce loaded models
$env:OLLAMA_MAX_LOADED_MODELS = 1

# Or reduce context
ollama run qwen3:32b --num-ctx 2048
```

### Slow Streaming

**Cause:** Network buffering or client-side issues.

**Fix:** Check API client settings:
```powershell
# Test direct API
curl http://localhost:11434/api/generate -d '{
  "model": "qwen3:32b",
  "prompt": "Hello",
  "stream": true
}'
```

## Recommended Configurations

### Interactive Chat (Single User)

```powershell
$env:OLLAMA_KEEP_ALIVE = "30m"
$env:OLLAMA_MAX_LOADED_MODELS = 2
$env:OLLAMA_NUM_PARALLEL = 1
```

### API Server (Multiple Users)

```powershell
$env:OLLAMA_KEEP_ALIVE = "1h"
$env:OLLAMA_MAX_LOADED_MODELS = 1  # Dedicate VRAM
$env:OLLAMA_NUM_PARALLEL = 4
```

### Batch Processing

```powershell
$env:OLLAMA_KEEP_ALIVE = "-1"  # Never unload
$env:OLLAMA_NUM_PARALLEL = 8
$env:OLLAMA_BATCH_SIZE = 1024
```
