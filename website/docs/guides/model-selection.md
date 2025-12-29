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

## RTX 5090 Optimized Stack (32GB VRAM)

The setup script installs an optimized combination for RTX 5090:

| Model | VRAM | Purpose |
|-------|------|---------|
| **qwen2.5:3b** | ~2GB | Fast web search queries |
| **qwen2.5:14b** | ~8GB | Synthesis & aggregation |
| **qwen2.5-coder:14b** | ~8GB | Code generation |

**Total: ~18GB** | **Remaining for context: ~14GB**

This leaves headroom for large context windows and concurrent model loading.

```powershell
# Install optimized stack
.\setup-ollama-websearch.ps1 -Setup OpenWebUI
```

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
| **qwen2.5:3b** | 3B | Lightning fast queries (~2GB VRAM) |
| **qwen2.5:14b** | 14B | Synthesize and aggregate results |
| **qwen3:32b** | 32B | Best at complex multi-source synthesis |
| **deepseek-r1:32b** | 32B | Deep analysis of sources |

**Why qwen2.5 for web search?** The qwen2.5 family offers excellent speed-to-quality ratio. The 3B model handles simple queries in milliseconds while the 14B provides deeper synthesis without the overhead of larger models.

## Community Models

High-quality community finetunes available via the `-CoderModels` flag.

| Model | Size | Context | Best For |
|-------|------|---------|----------|
| **NeuralNexusLab/CodeXor:20b** | ~14GB | 128K | Zero-omission coding (GPT-OSS base) |
| **NeuralNexusLab/CodeXor:12b** | ~9GB | 128K | **VISION** + coding (Gemma 3 base) |
| **mikepfunk28/deepseekq3_coder** | ~5GB | 128K | Coding with chain-of-thought |
| **mikepfunk28/deepseekq3_agent** | ~5GB | 128K | Agent/tool-calling tasks |
| **second_constantine/deepseek-coder-v2:16b** | ~9GB | 160K | Long-context coding |

### CodeXor - Zero-Omission Coding

[NeuralNexusLab/CodeXor](https://ollama.com/NeuralNexusLab/CodeXor) is engineered with a "zero-omission" philosophy - it won't use lazy placeholders like `// ... implement logic here`.

- **CodeXor:20b** - Based on OpenAI GPT-OSS 20B (Apache 2.0), matches o3-mini on coding benchmarks
- **CodeXor:12b** - Based on Google Gemma 3, includes **vision capability** for analyzing screenshots and diagrams

**Why community models?** These finetunes often combine strengths from multiple base models. The deepseekq3 series adds Qwen3's thinking capabilities to DeepSeek's coding prowess.

```powershell
# Install all coding models including community finetunes
.\setup-ollama.ps1 -CoderModels

# Or pull individually
ollama pull mikepfunk28/deepseekq3_coder
```

## Model Comparison Matrix

| Model | Coding | Reasoning | Chat | Creative | Speed |
|-------|--------|-----------|------|----------|-------|
| CodeXor:20b | ★★★★★ | ★★★★☆ | ★★★☆☆ | ★★☆☆☆ | ★★★☆☆ |
| CodeXor:12b | ★★★★☆ | ★★★☆☆ | ★★★☆☆ | ★★☆☆☆ | ★★★★☆ |
| qwen2.5:3b | ★★★☆☆ | ★★☆☆☆ | ★★★☆☆ | ★★☆☆☆ | ★★★★★ |
| qwen2.5:14b | ★★★★☆ | ★★★★☆ | ★★★★☆ | ★★★☆☆ | ★★★★☆ |
| qwen2.5-coder:14b | ★★★★★ | ★★★☆☆ | ★★★☆☆ | ★★☆☆☆ | ★★★★☆ |
| qwen3:32b | ★★★★★ | ★★★★☆ | ★★★★☆ | ★★★★☆ | ★★★☆☆ |
| deepseek-r1:32b | ★★★★☆ | ★★★★★ | ★★★☆☆ | ★★★☆☆ | ★★★☆☆ |
| llama3.3:70b | ★★★★☆ | ★★★★★ | ★★★★★ | ★★★★★ | ★★☆☆☆ |
| phi-4:14b | ★★★★☆ | ★★★★☆ | ★★★☆☆ | ★★☆☆☆ | ★★★★☆ |
| deepseekq3_coder | ★★★★☆ | ★★★★☆ | ★★★☆☆ | ★★☆☆☆ | ★★★★★ |

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
