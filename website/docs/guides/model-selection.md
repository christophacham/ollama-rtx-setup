---
sidebar_position: 1
---

# Model Selection Guide

Choosing the right model for your task. Updated December 2025.

## Why Model Choice Matters

Different models excel at different tasks. A model optimized for coding may struggle with creative writing. A reasoning-focused model may be overkill for simple chat.

**Key factors:**
- **Task type** - Coding, reasoning, chat, creative
- **Speed requirements** - Interactive vs. batch processing
- **VRAM budget** - What fits on your GPU
- **Accuracy needs** - When "good enough" vs. "best possible"

## Recommended Models by Task

### Coding & Development

| Model | Size | Why Choose It |
|-------|------|---------------|
| **qwen3:32b** | 32B | Best balance of coding ability and speed |
| **deepseek-coder-v2:16b** | 16B | Specialized for code, efficient |
| **codellama:34b** | 34B | Meta's code-focused model |

**Why Qwen3?** Alibaba's Qwen3 consistently outperforms similarly-sized models on coding benchmarks. The 32B variant fits comfortably on 24GB+ GPUs with excellent token throughput.

```powershell
ollama run qwen3:32b "Write a Python function to merge two sorted lists"
```

### Deep Reasoning

| Model | Size | Why Choose It |
|-------|------|---------------|
| **deepseek-r1:32b** | 32B | Chain-of-thought reasoning built-in |
| **qwen3:32b** | 32B | Strong reasoning with `/think` mode |
| **llama3.3:70b** | 70B | Largest open model, best raw capability |

**Why DeepSeek-R1?** DeepSeek-R1 was trained specifically for step-by-step reasoning. It "shows its work" naturally, making it excellent for math, logic, and complex analysis.

```powershell
ollama run deepseek-r1:32b "Prove that there are infinitely many prime numbers"
```

### General Chat & Assistance

| Model | Size | Why Choose It |
|-------|------|---------------|
| **llama3.1:8b** | 8B | Fast, capable, runs everywhere |
| **mistral:7b** | 7B | Excellent quality-to-size ratio |
| **gemma3:9b** | 9B | Google's efficient assistant model |

**Why Llama 3.1 8B?** Meta's Llama 3.1 8B offers remarkable capability in a small package. It loads in under a second and generates 80+ tokens/sec on modern GPUs.

### Creative Writing

| Model | Size | Why Choose It |
|-------|------|---------------|
| **llama3.3:70b** | 70B | Rich vocabulary, nuanced output |
| **qwen3:32b** | 32B | Excellent creative capabilities |
| **mistral-nemo:12b** | 12B | Good creativity, smaller footprint |

**Why larger models for creative work?** Creative tasks benefit from the larger "vocabulary" and more nuanced associations in bigger models. The quality difference is noticeable.

### Web Search & Research

| Model | Size | Why Choose It |
|-------|------|---------------|
| **qwen3:32b** | 32B | Best at synthesizing search results |
| **llama3.1:8b** | 8B | Fast for quick searches |
| **deepseek-r1:32b** | 32B | Deep analysis of sources |

## Model Comparison Matrix

| Model | Coding | Reasoning | Chat | Creative | Speed |
|-------|--------|-----------|------|----------|-------|
| qwen3:32b | ★★★★★ | ★★★★☆ | ★★★★☆ | ★★★★☆ | ★★★☆☆ |
| deepseek-r1:32b | ★★★★☆ | ★★★★★ | ★★★☆☆ | ★★★☆☆ | ★★★☆☆ |
| llama3.3:70b | ★★★★☆ | ★★★★★ | ★★★★★ | ★★★★★ | ★★☆☆☆ |
| llama3.1:8b | ★★★☆☆ | ★★★☆☆ | ★★★★☆ | ★★★☆☆ | ★★★★★ |
| mistral:7b | ★★★☆☆ | ★★★☆☆ | ★★★★☆ | ★★★☆☆ | ★★★★★ |
| phi-4:14b | ★★★★☆ | ★★★★☆ | ★★★☆☆ | ★★☆☆☆ | ★★★★☆ |

## Quantization Guide

Models come in different quantization levels. Lower quantization = smaller size but reduced quality.

| Quantization | Quality | Size Reduction | When to Use |
|--------------|---------|----------------|-------------|
| Q8_0 | 99% | 50% | When VRAM allows |
| Q6_K | 97% | 60% | Good balance |
| Q4_K_M | 95% | 70% | **Default choice** |
| Q4_0 | 92% | 75% | Tight VRAM |
| Q2_K | 85% | 85% | Last resort |

```powershell
# Pull specific quantization
ollama pull llama3.3:70b-instruct-q4_K_M
```

## Running Multiple Models

Ollama can keep multiple models loaded if VRAM permits:

```powershell
# Configure max loaded models
$env:OLLAMA_MAX_LOADED_MODELS = 3

# Models are loaded on-demand and cached
ollama run qwen3:32b "Hello"      # Loads qwen3
ollama run llama3.1:8b "Hello"    # Loads llama, keeps qwen3 if VRAM allows
```

**LRU eviction:** When VRAM fills, the least-recently-used model is unloaded automatically.

## Model Update Strategy

Models improve over time. Check for updates:

```powershell
# Update all models
ollama list | ForEach-Object { ollama pull ($_ -split '\s+')[0] }

# Check specific model
ollama show qwen3:32b --modelfile
```

## Custom Model Configuration

Create a Modelfile for custom settings:

```dockerfile
# Modelfile.coding
FROM qwen3:32b

PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_ctx 8192

SYSTEM "You are a senior software engineer. Write clean, well-documented code."
```

```powershell
ollama create coding-assistant -f Modelfile.coding
ollama run coding-assistant
```
