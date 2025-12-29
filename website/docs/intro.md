---
sidebar_position: 1
slug: /
---

# Ollama RTX Setup

**Run powerful AI models locally on your NVIDIA GPU - private, fast, and free.**

## Why Local AI?

### Privacy First
Your prompts, code, and data never leave your machine. No API logging, no data retention policies, no third-party access. What happens on your GPU stays on your GPU.

### Zero Recurring Costs
After the initial hardware investment, there are no API fees, no token limits, no rate limiting. Run as many queries as you want, whenever you want.

### Latency Matters
Local inference eliminates network round-trips. On a modern RTX GPU, you get responses in milliseconds, not seconds. This makes a real difference for iterative workflows.

### Full Control
Choose your models, configure your context windows, adjust parameters. No waiting for providers to update. No sudden deprecations or pricing changes.

## Why Ollama?

We chose [Ollama](https://ollama.ai) as the foundation for this setup:

| Feature | Ollama | llama.cpp | vLLM |
|---------|--------|-----------|------|
| **Setup complexity** | One-liner install | Compile from source | Python environment |
| **Model management** | `ollama pull` | Manual GGUF download | HuggingFace config |
| **GPU optimization** | Automatic | Manual flags | Requires tuning |
| **Windows support** | Native | WSL required | Limited |
| **API compatibility** | OpenAI-compatible | Custom | OpenAI-compatible |

Ollama provides the simplest path from "nothing installed" to "chatting with a 70B model" - often in under 5 minutes.

## Choose Your Setup

```
┌─────────────────────────────────────────────────────────────┐
│                 What do you want to do?                     │
└─────────────────────────────────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
   Just run models    Chat interface    AI Research
   (API/terminal)     with web search   (Perplexity-like)
         │                 │                 │
         ▼                 ▼                 ▼
   ┌─────────────┐  ┌─────────────┐  ┌──────────────┐
   │   Ollama    │  │ Open WebUI  │  │  Perplexica  │
   │    only     │  │  (± SearXNG)│  │  + SearXNG   │
   └─────────────┘  └─────────────┘  └──────────────┘
    setup-ollama     setup-ollama-     setup-ollama-
       .ps1          websearch.ps1     websearch.ps1
                     -Setup OpenWebUI  -Setup Perplexica
```

| Want This? | Run This | What You Get |
|------------|----------|--------------|
| Just AI chat (terminal) | `setup-ollama.ps1` | Ollama + models |
| Chat UI (ready to use) | `setup-ollama-websearch.ps1 -Setup OpenWebUI -SingleUser` | Open WebUI, no login needed |
| Chat UI + web search | `setup-ollama-websearch.ps1 -Setup OpenWebUI` | + Open WebUI |
| AI research with citations | `setup-ollama-websearch.ps1 -Setup Perplexica` | + Perplexica + SearXNG |
| Everything | `setup-ollama-websearch.ps1 -Setup Both` | All of the above |

:::tip Recommended for personal use
Use `-SingleUser` to skip account creation - Open WebUI will be ready to use immediately with web search pre-enabled.
:::

## What This Repository Provides

### Setup Scripts
Automated installation and configuration for Ollama, optimized for NVIDIA RTX GPUs (especially the RTX 5090 with 32GB VRAM).

### Model Recommendations
Curated model lists based on extensive testing - which models excel at coding, reasoning, creative writing, and web search tasks.

### Web Search Integration
Two options for AI-powered web search:
- **[Open WebUI](/guides/web-search#option-1-open-webui)** - ChatGPT-like interface, uses one search engine at a time
- **[Perplexica](/guides/web-search#option-2-perplexica--searxng)** - Perplexity AI alternative, uses SearXNG to search multiple engines at once

See [Web Search Integration](/guides/web-search) to understand the difference.

### Management Tools
- **ollama-manager** - Terminal UI for loading/unloading models
- **Backup/restore scripts** - Move your models between machines
- **Bandwidth limiter** - Prevent network saturation during large downloads
- **Container image mirroring** - Self-hosted container registry

## Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **GPU** | RTX 3060 (12GB) | RTX 4090 (24GB) or RTX 5090 (32GB) |
| **VRAM** | 12GB | 24-32GB |
| **RAM** | 16GB | 32GB+ |
| **Storage** | 50GB SSD | 200GB+ NVMe |

More VRAM = larger models = better results. A 32GB GPU can run 70B parameter models at full precision, while 12GB limits you to 7-13B models.

## Quick Start

```powershell
# Clone the repository
git clone https://github.com/christophacham/ollama-rtx-setup.git
cd ollama-rtx-setup

# Run the setup script
.\setup-ollama.ps1

# That's it! Start chatting:
ollama run qwen3:32b
```

Ready to dive deeper? Start with the [Quick Start Guide](/getting-started/quick-start).
