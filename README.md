# Ollama RTX Setup

Complete setup for running powerful local AI models with Ollama on NVIDIA RTX 5090 (32GB VRAM) or similar high-end GPUs. Includes web search integration via Open WebUI and Perplexica.

> **Last Updated:** December 2025 - Includes DeepSeek-R1-0528, Qwen3, Phi-4, Gemma 3, and Llama 3.3

## Features

- **Zero API costs** - Run unlimited queries locally
- **Complete privacy** - Your data never leaves your machine
- **Web search** - Real-time internet access for your AI
- **Optimized for RTX 5090** - Best models for 32GB VRAM
- **One-click setup** - Automated PowerShell scripts
- **Smart detection** - Only downloads missing models

## Quick Start

```powershell
# 1. Install Ollama and download best models
.\setup-ollama.ps1

# 2. Add web search capabilities
.\setup-ollama-websearch.ps1
```

## Hardware Requirements

### RTX 5090 (Optimal Target)

| Spec | Value |
|------|-------|
| VRAM | 32GB GDDR7 |
| Memory Bandwidth | 1,792 GB/s |
| Memory Bus | 512-bit |
| Best For | 32B-34B parameter models |

### Other Supported GPUs

| GPU | VRAM | Recommended Models |
|-----|------|-------------------|
| RTX 4090 | 24GB | 14B-32B (Q4_K_M) |
| RTX 4080 | 16GB | 8B-14B models |
| RTX 3090 | 24GB | 14B-32B (Q4_K_M) |
| RTX 3080 | 10GB | 7B-8B models |

## Recommended Models (2025)

### Tier 1: Flagship Models (32GB VRAM)

| Model | Size | Best For | VRAM | Context | Notes |
|-------|------|----------|------|---------|-------|
| **qwen2.5-coder:32b** | ~19GB | Coding | ~22GB | 131K | Best local coding model, 92 languages, rivals GPT-4o |
| **deepseek-r1:32b** | ~20GB | Reasoning | ~24GB | 128K | Chain-of-thought reasoning, MIT license, v0528 update |
| **qwen3:32b** | ~19GB | General + Code | ~22GB | 131K | Dual mode: thinking/non-thinking, Apache 2.0 |
| **llama3.3:70b-q4** | ~40GB | General | ~42GB | 128K | Rivals Llama 3.1 405B, needs Q4 quantization |

### Tier 2: Efficient Models (16-24GB VRAM)

| Model | Size | Best For | VRAM | Context | Notes |
|-------|------|----------|------|---------|-------|
| **gemma3:27b** | ~16GB | General | ~18GB | 128K | Google's latest, outperforms larger models |
| **phi4:14b** | ~9GB | Reasoning | ~11GB | 32K | Microsoft's efficient model, rivals 70B performance |
| **deepseek-coder:33b** | ~19GB | Coding | ~22GB | 16K | 87 languages, strong alternative |
| **codellama:34b** | ~19GB | Coding | ~22GB | 16K | Meta's coding model, 20+ languages |

### Tier 3: Fast Models (8-12GB VRAM)

| Model | Size | Best For | VRAM | Context | Notes |
|-------|------|----------|------|---------|-------|
| **llama3.1:8b** | ~5GB | Web search | ~6GB | 131K | Fast with tool calling support |
| **gemma3:12b** | ~7GB | General | ~9GB | 128K | Good balance of speed and quality |
| **phi4:14b** | ~9GB | Reasoning | ~11GB | 32K | Efficient reasoning, function calling |
| **mistral:7b** | ~4GB | Quick queries | ~5GB | 32K | Lightweight, good for simple tasks |

## Setup Scripts

### `setup-ollama.ps1`

Installs Ollama and downloads optimal models:

```powershell
.\setup-ollama.ps1              # Full setup (3 core models)
.\setup-ollama.ps1 -MinimalModels   # Just qwen2.5-coder:32b
.\setup-ollama.ps1 -AllModels       # All 5 recommended models
.\setup-ollama.ps1 -Help            # Show options
```

### `setup-ollama-websearch.ps1`

Adds web search capabilities:

```powershell
.\setup-ollama-websearch.ps1                     # Install Open WebUI
.\setup-ollama-websearch.ps1 -Setup Perplexica   # Install Perplexica
.\setup-ollama-websearch.ps1 -Setup Both         # Install both
.\setup-ollama-websearch.ps1 -Uninstall          # Remove containers
```

## Web Search Options

### Option 1: Open WebUI (Recommended)

Beautiful ChatGPT-like interface with built-in web search.

```powershell
# Or use docker-compose directly
docker-compose -f docker-compose-openwebui.yml --profile gpu up -d
```

Access at: http://localhost:3000

**Features:**
- 15+ search providers (DuckDuckGo, Google, Brave, etc.)
- RAG (Retrieval Augmented Generation)
- Beautiful modern UI
- Single container setup

### Option 2: Perplexica (Full Privacy)

100% local Perplexity AI alternative with SearXNG.

```powershell
docker-compose -f docker-compose-perplexica.yml up -d
```

Access at:
- Perplexica: http://localhost:3002
- SearXNG: http://localhost:4000

**Features:**
- Complete privacy - searches never leave your machine
- AI-powered answer synthesis with citations
- Multiple search modes (Academic, YouTube, Reddit, etc.)

## Model Selection Guide

| Task | Primary Model | Alternative | Notes |
|------|--------------|-------------|-------|
| Code completion | qwen2.5-coder:32b | deepseek-coder:33b | Best benchmarks on EvalPlus, LiveCodeBench |
| Code review | qwen2.5-coder:32b | qwen3:32b | Qwen3 adds reasoning for complex reviews |
| Debugging | deepseek-r1:32b | phi4:14b | DeepSeek shows step-by-step thinking |
| Complex reasoning | deepseek-r1:32b | qwen3:32b | Both have chain-of-thought capabilities |
| Math & Logic | deepseek-r1:32b | phi4:14b | Phi-4 rivals 70B on AIME 2025 |
| Web search | qwen3:32b | llama3.1:8b | Llama 3.1 for speed, Qwen3 for quality |
| General chat | gemma3:27b | qwen3:32b | Gemma3 outperforms on LMArena |
| Quick queries | phi4:14b | mistral:7b | Phi-4 best quality-to-size ratio |

### New in 2025

| Model | Release | Highlights |
|-------|---------|------------|
| DeepSeek-R1-0528 | May 2025 | Major reasoning upgrade, approaches O3/Gemini 2.5 Pro |
| Qwen3 | Apr 2025 | Dual thinking modes, surpasses QwQ and Qwen2.5 |
| Phi-4 | Jan 2025 | 14B model rivaling 70B performance, MIT license |
| Gemma 3 | Mar 2025 | Outperforms Llama 3.1 405B, DeepSeek-V3, o3-mini |
| Llama 3.3 | Dec 2024 | 70B matching 405B performance |

## Performance Optimization

### Enable Flash Attention

```powershell
$env:OLLAMA_FLASH_ATTENTION = "1"
```

### Full GPU Offload

```powershell
$env:OLLAMA_NUM_GPU = "999"
```

### Increase Context Window

```powershell
$env:OLLAMA_NUM_CTX = "8192"
```

### Docker Access

```powershell
$env:OLLAMA_HOST = "0.0.0.0"
```

## Files Included

| File | Description |
|------|-------------|
| `setup-ollama.ps1` | Main Ollama setup script |
| `setup-ollama-websearch.ps1` | Web search setup script |
| `docker-compose-openwebui.yml` | Open WebUI Docker config |
| `docker-compose-perplexica.yml` | Perplexica + SearXNG Docker config |
| `custom_models.json` | Model configurations for PAL MCP |

## Requirements

- Windows 10/11 (64-bit)
- NVIDIA GPU with 10GB+ VRAM
- [Ollama](https://ollama.com/download)
- [Docker Desktop](https://docker.com) or [Podman](https://podman.io) (for web search)
- PowerShell 5.1+

**Container Runtime:** Scripts automatically detect Docker or Podman (Docker preferred).

## Troubleshooting

### Ollama Not Running

```powershell
ollama serve
```

### Docker Connection Issues

```powershell
$env:OLLAMA_HOST = "0.0.0.0"
# Restart Ollama
```

### VRAM Out of Memory

Use smaller quantization or models:
```powershell
ollama pull qwen2.5-coder:14b
```

## Sources

### Hardware
- [NVIDIA RTX 5090 Specs](https://www.nvidia.com/en-us/geforce/graphics-cards/50-series/rtx-5090/)
- [Ollama VRAM Requirements Guide](https://localllm.in/blog/ollama-vram-requirements-for-local-llms)

### Models
- [Ollama Model Library](https://ollama.com/library)
- [Best Ollama Models 2025](https://collabnix.com/best-ollama-models-in-2025-complete-performance-comparison/)
- [Best Ollama Models for Coding](https://www.codegpt.co/blog/best-ollama-model-for-coding)
- [DeepSeek-R1 on Ollama](https://ollama.com/library/deepseek-r1)
- [Qwen3 on Ollama](https://ollama.com/library/qwen3)
- [Phi-4 on Ollama](https://ollama.com/library/phi4)
- [Gemma 3 Announcement](https://blog.google/technology/developers/gemma-3/)

### Web Search
- [Ollama Documentation](https://github.com/ollama/ollama)
- [Open WebUI](https://github.com/open-webui/open-webui)
- [Perplexica](https://github.com/ItzCrazyKns/Perplexica)

## License

MIT License - See [LICENSE](LICENSE)
