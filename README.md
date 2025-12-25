# Ollama RTX Setup

Complete setup for running powerful local AI models with Ollama on NVIDIA RTX 5090 (32GB VRAM) or similar high-end GPUs. Includes web search integration via Open WebUI and Perplexica.

## Features

- **Zero API costs** - Run unlimited queries locally
- **Complete privacy** - Your data never leaves your machine
- **Web search** - Real-time internet access for your AI
- **Optimized for RTX 5090** - Best models for 32GB VRAM
- **One-click setup** - Automated PowerShell scripts

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

## Recommended Models

| Model | Size | Best For | VRAM | Context |
|-------|------|----------|------|---------|
| **qwen2.5-coder:32b** | ~19GB | Coding (92 languages) | ~22GB | 131K |
| **deepseek-r1:32b** | ~19GB | Complex reasoning | ~24GB | 131K |
| **qwen3:32b** | ~19GB | General reasoning | ~22GB | 131K |
| **llama3.1:8b** | ~5GB | Fast web search | ~6GB | 131K |
| **mistral:7b** | ~4GB | Quick queries | ~5GB | 32K |

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

| Task | Primary Model | Alternative |
|------|--------------|-------------|
| Code completion | qwen2.5-coder:32b | deepseek-coder:33b |
| Code review | qwen2.5-coder:32b | codellama:34b |
| Debugging | deepseek-r1:32b | qwen3:32b |
| Complex reasoning | deepseek-r1:32b | qwen3:32b |
| Web search | qwen3:32b | llama3.1:8b |
| Quick queries | llama3.1:8b | mistral:7b |

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
- [Docker Desktop](https://docker.com) (for web search)
- PowerShell 5.1+

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

- [NVIDIA RTX 5090 Specs](https://www.nvidia.com/en-us/geforce/graphics-cards/50-series/rtx-5090/)
- [Ollama Documentation](https://github.com/ollama/ollama)
- [Open WebUI](https://github.com/open-webui/open-webui)
- [Perplexica](https://github.com/ItzCrazyKns/Perplexica)
- [Best Ollama Models 2025](https://collabnix.com/best-ollama-models-in-2025-complete-performance-comparison/)

## License

MIT License - See [LICENSE](LICENSE)
