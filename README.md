# Ollama RTX Setup

Complete setup for running powerful local AI models with Ollama on NVIDIA RTX 5090 (32GB VRAM) or similar high-end GPUs. Includes web search integration via Open WebUI and Perplexica.

> **Last Updated:** December 2025 - Includes DeepSeek-R1-0528, Qwen3, Phi-4, Gemma 3, and Llama 3.3

**[Full Documentation](https://christophacham.github.io/ollama-rtx-setup)** | [Quick Start](#quick-start) | [Model Guide](#recommended-models-2025) | [Troubleshooting](#troubleshooting)

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
| **qwen2.5:3b** | ~2GB | Web search | ~3GB | 32K | Lightning fast queries |
| **qwen2.5:14b** | ~8GB | Synthesis | ~10GB | 32K | Balance of speed and quality |
| **qwen2.5-coder:14b** | ~8GB | Coding | ~10GB | 32K | Efficient code generation |
| **gemma3:12b** | ~7GB | General | ~9GB | 128K | Good balance of speed and quality |
| **phi4:14b** | ~9GB | Reasoning | ~11GB | 32K | Efficient reasoning, function calling |

### Web Search Optimized Stack (RTX 5090)

The `setup-ollama-websearch.ps1` installs a specialized stack:

| Model | VRAM | Purpose |
|-------|------|---------|
| qwen2.5:3b | ~4GB | Fast web queries |
| qwen2.5-coder:14b | ~17GB | Synthesis and code |

**Total: ~21GB** - both models fit in VRAM simultaneously, leaving ~11GB for context.

### Community Finetunes

High-quality community models from Ollama library.

| Model | Size | Best For | Context | Notes |
|-------|------|----------|---------|-------|
| **mikepfunk28/deepseekq3_coder** | ~5GB | Coding | 128K | DeepSeek + Qwen3 thinking, tools support |
| **mikepfunk28/deepseekq3_agent** | ~5GB | Agents | 128K | Agent-focused variant with tool calling |
| **second_constantine/deepseek-coder-v2:16b** | ~9GB | Coding | 160K | MoE architecture, IQ4_XS quantized |

### Uncensored Models (No Content Filters)

Models with alignment/safety filters removed. Use responsibly.

| Model | Size | Best For | VRAM | Author |
|-------|------|----------|------|--------|
| **dolphin3:8b** | ~5GB | General, agentic | ~6GB | Eric Hartford |
| **dolphin-mistral:7b** | ~4GB | Coding | ~5GB | Eric Hartford |
| **wizard-vicuna-uncensored:13b** | ~8GB | Assistant | ~10GB | Eric Hartford |
| **llama2-uncensored:7b** | ~4GB | General | ~5GB | George Sung |
| **dolphin-phi** | ~2GB | Lightweight | ~3GB | Eric Hartford |

## Setup Scripts

### `setup-ollama.ps1`

Installs Ollama and downloads optimal models:

```powershell
.\setup-ollama.ps1                  # Full setup (3 core models)
.\setup-ollama.ps1 -MinimalModels   # Just qwen2.5-coder:32b
.\setup-ollama.ps1 -AllModels       # All recommended models
.\setup-ollama.ps1 -CoderModels     # Coding-focused models only (10 models)
.\setup-ollama.ps1 -Help            # Show options
```

### `setup-uncensored-models.ps1`

Downloads uncensored models (requires Ollama already installed):

```powershell
.\setup-uncensored-models.ps1              # Install missing uncensored models
.\setup-uncensored-models.ps1 -ForceDownload   # Re-download all
.\setup-uncensored-models.ps1 -Help            # Show options
```

### `backup-ollama-models.ps1`

Backup and restore your Ollama models to/from external storage:

```powershell
.\backup-ollama-models.ps1                            # Interactive mode
.\backup-ollama-models.ps1 -Mode Backup -Path "F:\Backups\Ollama"
.\backup-ollama-models.ps1 -Mode Restore -Path "F:\Backups\Ollama"
.\backup-ollama-models.ps1 -Mode Info                 # Show storage info
```

**Features:**
- Uses `robocopy` for reliable large file transfers with progress
- Automatically stops Ollama before operations
- Option to set `OLLAMA_MODELS` env var to use backup location directly
- Disk space verification before backup

### `setup-ollama-websearch.ps1`

Adds web search capabilities with optimized models and integrated testing:

```powershell
# Recommended: Single-user mode (no login required)
.\setup-ollama-websearch.ps1 -Setup OpenWebUI -SingleUser

.\setup-ollama-websearch.ps1                     # Interactive menu
.\setup-ollama-websearch.ps1 -Setup Perplexica   # Install Perplexica
.\setup-ollama-websearch.ps1 -Setup Both         # Install both
.\setup-ollama-websearch.ps1 -Uninstall          # Remove containers
```

**Features:**
- Pulls 3 optimized models (qwen2.5:3b, qwen2.5:14b, qwen2.5-coder:14b)
- Runs automated inference & web search testing
- Pre-configures Open WebUI with web search enabled

## Web Search Options

### Option 1: Open WebUI (Recommended)

Beautiful ChatGPT-like interface with SearXNG multi-engine search.

```powershell
# Or use docker-compose directly
docker-compose -f docker-compose-openwebui.yml --profile gpu up -d
```

Access at:
- Open WebUI: http://localhost:3000
- SearXNG: http://localhost:4000

**Features:**
- Multi-engine search via SearXNG (DuckDuckGo, Google, Brave, etc.)
- RAG (Retrieval Augmented Generation)
- Beautiful modern UI
- Self-hosted, no rate limits

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
| Code completion | qwen2.5-coder:32b | qwen2.5-coder:14b | 14b for faster responses |
| Code review | qwen2.5-coder:32b | qwen3:32b | Qwen3 adds reasoning for complex reviews |
| Debugging | deepseek-r1:32b | phi4:14b | DeepSeek shows step-by-step thinking |
| Complex reasoning | deepseek-r1:32b | qwen3:32b | Both have chain-of-thought capabilities |
| Math & Logic | deepseek-r1:32b | phi4:14b | Phi-4 rivals 70B on AIME 2025 |
| Web search (fast) | qwen2.5:3b | qwen2.5:14b | 3b for queries, 14b for synthesis |
| Web search (deep) | qwen3:32b | deepseek-r1:32b | For complex multi-source analysis |
| General chat | gemma3:27b | qwen3:32b | Gemma3 outperforms on LMArena |
| Quick queries | qwen2.5:3b | phi4:14b | qwen2.5:3b fastest at ~2GB VRAM |

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
| `setup-uncensored-models.ps1` | Uncensored models installer |
| `backup-ollama-models.ps1` | Backup/restore models to external storage |
| `setup-ollama-websearch.ps1` | Web search setup script |
| `docker-compose-openwebui.yml` | Open WebUI Docker config |
| `docker-compose-perplexica.yml` | Perplexica + SearXNG Docker config |
| `custom_models.json` | Model configurations for PAL MCP (see below) |

## PAL MCP Integration (custom_models.json)

The `custom_models.json` file configures local Ollama models for use with [PAL MCP Server](https://github.com/BeehiveInnovations/pal-mcp-server).

### Usage

Copy to your PAL MCP server's `conf/` directory:

```powershell
# Copy to PAL MCP config
Copy-Item custom_models.json "C:\path\to\pal-mcp-server\conf\"
```

### Model Categories

| Category | Description | Example Models |
|----------|-------------|----------------|
| `coder` | Coding-focused models | qwen2.5-coder:32b, devstral-small-2 |
| `reasoning` | Extended thinking/CoT | deepseek-r1:32b, qwen3:32b, phi4:14b |
| `general` | General purpose | gemma3:27b, llama3.1:8b, mistral:7b |
| `uncensored` | No content filters | dolphin3:8b, dolphin-mistral:7b |
| `community` | Community finetunes | mikepfunk28/deepseekq3_coder |

### Model Aliases

Each model has short aliases for easy reference in PAL:

```
"Use qwen-coder to review this code"     # → qwen2.5-coder:32b
"Use deepseek to debug this"             # → deepseek-r1:32b
"Use dscoder for this task"              # → mikepfunk28/deepseekq3_coder
```

### Fields Reference

| Field | Description |
|-------|-------------|
| `model_name` | Ollama model name (e.g., `qwen2.5-coder:32b`) |
| `aliases` | Short names for the model (case-insensitive) |
| `context_window` | Max input tokens |
| `max_output_tokens` | Max response tokens |
| `supports_extended_thinking` | Has chain-of-thought reasoning |
| `supports_json_mode` | Can output structured JSON |
| `supports_function_calling` | Has tool/function calling |
| `intelligence_score` | Relative capability (1-20) |
| `category` | Model category for organization |

## Requirements

- Windows 10/11 (64-bit)
- NVIDIA GPU with 10GB+ VRAM
- [Ollama](https://ollama.com/download)
- [Docker Desktop](https://docker.com) or [Podman](https://podman.io) (for web search)
- PowerShell 5.1+

**Container Runtime:** Scripts automatically detect Docker or Podman (Docker preferred).

## Troubleshooting

See the [full troubleshooting guide](https://christophacham.github.io/ollama-rtx-setup/troubleshooting/common-issues) for detailed solutions.

### Ollama Not Running

```powershell
ollama serve
```

### Docker Connection Issues

```powershell
$env:OLLAMA_HOST = "0.0.0.0"
# Restart Ollama
```

### Podman + Ollama Connectivity

If using Podman and containers can't reach Ollama, run the debug script:

```powershell
.\debug-ollama-connection.ps1 -Fix
```

See [Podman + Ollama Connectivity](https://christophacham.github.io/ollama-rtx-setup/troubleshooting/podman-ollama) for details.

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
