---
sidebar_position: 1
---

# Model Configuration Reference

Complete reference for PAL MCP Server model stack. Updated January 2026.

## Overview

PAL uses a **minimal, focused model stack** - 4 local Ollama models + 5 OpenRouter cloud models. Each model has a specific purpose with no redundancy.

## Local Models (Ollama)

These run on your RTX 5090 (32GB VRAM) via Ollama:

| Model | Aliases | VRAM | Use Case |
|-------|---------|------|----------|
| `qwen2.5-coder:32b` | `coder`, `code`, `qwen` | ~19GB | Best local coding, 92 languages, rivals GPT-4o |
| `deepseek-r1:32b` | `deepseek`, `r1`, `reasoning`, `think` | ~20GB | Best local reasoning, approaches O3 |
| `qwen2.5:3b` | `quick`, `fast`, `small`, `3b` | ~2GB | Ultra-fast for simple tasks |
| `dolphin3:8b` | `dolphin`, `uncensored`, `unfiltered` | ~5GB | Uncensored, no safety filters |

### Usage Examples

```bash
# Coding tasks
pal coder "Write a Python async HTTP client"

# Deep reasoning
pal reasoning "Analyze the time complexity of this algorithm"

# Quick simple tasks
pal quick "What's 2+2?"

# Unrestricted tasks
pal uncensored "Explain how X works without caveats"
```

### Installation

```powershell
# Install all 4 core models (default)
.\setup-ollama.ps1

# Minimal: just coder + reasoning
.\setup-ollama.ps1 -MinimalModels

# Full: adds qwen3:32b and phi4:14b
.\setup-ollama.ps1 -AllModels
```

## Cloud Models (OpenRouter)

These run via OpenRouter API for tasks requiring massive context, multimodal, or cloud capabilities:

| Model | Aliases | Context | Use Case |
|-------|---------|---------|----------|
| `meta-llama/llama-4-maverick` | `maverick`, `llama4`, `vision`, `multimodal`, `images` | 1M | Image analysis, multimodal, 12 languages |
| `deepseek/deepseek-v3.2` | `deepseek-v3`, `v3.2`, `deepseek-cloud`, `workhorse` | 164K | GPT-5 class reasoning, bulk work |
| `minimax/minimax-m2.1` | `minimax`, `m2.1`, `m2` | 196K | Coding/agentic workflows, 49.4% Multi-SWE-Bench |
| `z-ai/glm-4.7` | `glm`, `glm4`, `glm-4.7` | 203K | Multi-step reasoning/execution |
| `mistralai/devstral-2512:free` | `devstral`, `devstral2`, `mistral-code`, `mistral-free` | 262K | Agentic coding specialist, **FREE** |
| `xiaomi/mimo-v2-flash:free` | `mimo`, `mimo-flash`, `xiaomi` | 262K | Multimodal vision, **FREE** |

### Pricing Reference

| Model | Input | Output | Notes |
|-------|-------|--------|-------|
| Llama 4 Maverick | $0.15/M | $0.60/M | Cheapest multimodal, 1M context |
| DeepSeek V3.2 | ~$0.27/M | ~$1.10/M | GPT-5 class workhorse |
| MiniMax M2.1 | $0.28/M | $1.20/M | Best for agentic coding |
| GLM 4.7 | $0.40/M | $1.50/M | Z.AI flagship reasoning |
| Devstral 2 | **FREE** | **FREE** | 123B dense, MIT license |
| MiMo V2 Flash | **FREE** | **FREE** | Xiaomi multimodal |

### Usage Examples

```bash
# Image analysis
pal vision "Analyze this architecture diagram" --image diagram.png

# Heavy cloud reasoning
pal workhorse "Refactor this 2000-line file"

# Free agentic coding
pal devstral "Build a REST API with error handling"

# Free multimodal
pal mimo "Describe what's in this screenshot" --image screen.png

# Multi-step reasoning
pal glm "Debug this complex async issue step by step"
```

## Complete Alias Reference

### Local (Ollama)

```
coder, code, qwen       → qwen2.5-coder:32b
deepseek, r1, reasoning, think → deepseek-r1:32b
quick, fast, small, 3b  → qwen2.5:3b
dolphin, uncensored, unfiltered → dolphin3:8b
```

### Cloud (OpenRouter)

```
maverick, llama4, vision, multimodal, images → meta-llama/llama-4-maverick
deepseek-v3, v3.2, deepseek-cloud, workhorse → deepseek/deepseek-v3.2
minimax, m2.1, m2 → minimax/minimax-m2.1
glm, glm4, glm-4.7 → z-ai/glm-4.7
devstral, devstral2, mistral-code, mistral-free → mistralai/devstral-2512:free
mimo, mimo-flash, xiaomi → xiaomi/mimo-v2-flash:free
```

## Routing Logic

PAL automatically routes based on task type:

| Task Type | Model Used |
|-----------|------------|
| Coding | `qwen2.5-coder:32b` (local) or `mistralai/devstral-2512:free` (cloud, FREE) |
| Reasoning | `deepseek-r1:32b` (local) or `z-ai/glm-4.7` (cloud) |
| Quick tasks | `qwen2.5:3b` (local) |
| Image analysis | `meta-llama/llama-4-maverick` (cloud) or `xiaomi/mimo-v2-flash:free` (FREE) |
| Agentic tools | `minimax/minimax-m2.1` (cloud) |
| Heavy lifting | `deepseek/deepseek-v3.2` (cloud) |

## Configuration Files

### Local Models: `custom_models.json`

```json
{
  "models": [
    {
      "model_name": "qwen2.5-coder:32b-5090",
      "aliases": ["qwen-coder", "coder", "code", "qwen"],
      "intelligence_score": 18
    }
  ]
}
```

### Cloud Models: `openrouter_models.json`

```json
{
  "models": [
    {
      "model_name": "mistralai/devstral-2512:free",
      "aliases": ["devstral", "devstral2", "mistral-code", "mistral-free"],
      "context_window": 262144
    }
  ]
}
```

## VRAM Management

With RTX 5090 (32GB), you can run:

- **One large model**: qwen2.5-coder:32b (~19GB) + context
- **Two medium models**: deepseek-r1:32b + qwen2.5:3b
- **Small + large**: Any 32B model + qwen2.5:3b (runs alongside)

Ollama uses LRU eviction - least recently used models are unloaded when VRAM fills.

```powershell
# Configure max concurrent models
$env:OLLAMA_MAX_LOADED_MODELS = 2
```

## Optimized Variants

After downloading base models, run the optimizer to create RTX 5090 variants:

```powershell
.\optimize-ollama-5090.ps1
```

This creates `-5090` suffixed models with optimal quantization and context settings.
