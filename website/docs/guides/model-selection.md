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

These run via OpenRouter API for tasks requiring web search, massive context, or cloud capabilities:

| Model | Aliases | Context | Use Case |
|-------|---------|---------|----------|
| `x-ai/grok-4.1-fast` | `grok`, `grok4`, `agentic`, `tool-calling` | 2M | Best agentic tool calling |
| `meta-llama/llama-4-maverick` | `maverick`, `llama4`, `vision`, `multimodal`, `images` | 1M | Image analysis, multimodal |
| `deepseek/deepseek-v3.2` | `deepseek-v3`, `v3.2`, `deepseek-cloud`, `workhorse` | 164K | Heavy reasoning, bulk work |
| `perplexity/sonar-reasoning` | `sonar-reasoning`, `web-search`, `research`, `perplexity` | 127K | Web search + DeepSeek R1 reasoning |
| `perplexity/sonar` | `sonar`, `quick-search`, `sonar-cheap` | 127K | Cheapest web search |

### Pricing Reference

| Model | Input | Output | Notes |
|-------|-------|--------|-------|
| Grok 4.1 Fast | $0.20/M | $0.50/M | Cheapest 2M context |
| Llama 4 Maverick | $0.15/M | $0.60/M | Cheapest multimodal |
| DeepSeek V3.2 | ~$0.27/M | ~$1.10/M | GPT-5 class |
| Sonar Reasoning | $1/M | $5/M | +$5/K requests |
| Sonar | $1/M | $1/M | +$5/K requests |

### Usage Examples

```bash
# Web search with reasoning
pal web-search "Latest Rust async patterns 2026"

# Image analysis
pal vision "Analyze this architecture diagram" --image diagram.png

# Agentic multi-step tasks
pal grok "Research and summarize top 5 Go frameworks"

# Heavy cloud reasoning
pal workhorse "Refactor this 2000-line file"

# Quick cheap web lookup
pal sonar "What time is it in Tokyo?"
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
grok, grok4, agentic, tool-calling → x-ai/grok-4.1-fast
maverick, llama4, vision, multimodal, images → meta-llama/llama-4-maverick
deepseek-v3, v3.2, deepseek-cloud, workhorse → deepseek/deepseek-v3.2
sonar-reasoning, web-search, research, perplexity → perplexity/sonar-reasoning
sonar, quick-search, sonar-cheap → perplexity/sonar
```

## Routing Logic

PAL automatically routes based on task type:

| Task Type | Model Used |
|-----------|------------|
| Coding | `qwen2.5-coder:32b` (local) |
| Reasoning | `deepseek-r1:32b` (local) |
| Quick tasks | `qwen2.5:3b` (local) |
| Web search | `perplexity/sonar-reasoning` (cloud) |
| Image analysis | `meta-llama/llama-4-maverick` (cloud) |
| Agentic tools | `x-ai/grok-4.1-fast` (cloud) |
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
      "model_name": "perplexity/sonar-reasoning",
      "aliases": ["sonar-reasoning", "web-search", "research"],
      "context_window": 127000
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
