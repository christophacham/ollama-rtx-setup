---
sidebar_position: 1
---

# Quick Start

Get Ollama running with recommended models in under 5 minutes.

## Prerequisites

- **Windows 10/11** (64-bit)
- **NVIDIA GPU** with 12GB+ VRAM
- **NVIDIA Drivers** (version 525+ for CUDA 12)
- **PowerShell 5.1+** (included with Windows)

## Step 1: Clone the Repository

```powershell
git clone https://github.com/christophacham/ollama-rtx-setup.git
cd ollama-rtx-setup
```

## Step 2: Run Setup

```powershell
.\setup-ollama.ps1
```

This script will:
1. Check for NVIDIA GPU and drivers
2. Install Ollama if not present
3. Download recommended models based on your VRAM

### What Gets Installed

| VRAM | Models Installed |
|------|------------------|
| 32GB | qwen3:32b, deepseek-r1:32b, llama3.3:70b-instruct-q4_K_M |
| 24GB | qwen3:32b, deepseek-r1:32b, qwen2.5:14b |
| 12GB | qwen3:14b, qwen2.5:3b, qwen2.5-coder:14b |

### Web Search Optimized Stack (RTX 5090)

For web search use cases, the setup installs a specialized stack:

```powershell
.\setup-ollama-websearch.ps1 -Setup OpenWebUI -SingleUser
```

| Model | VRAM | Purpose |
|-------|------|---------|
| qwen2.5:3b | ~2GB | Fast web queries |
| qwen2.5:14b | ~8GB | Synthesis |
| qwen2.5-coder:14b | ~8GB | Code generation |

**Total: ~18GB** leaving ~14GB for context windows.

## Step 3: Start Chatting

```powershell
# Interactive chat
ollama run qwen3:32b

# Or use the API
curl http://localhost:11434/api/chat -d '{
  "model": "qwen3:32b",
  "messages": [{"role": "user", "content": "Hello!"}]
}'
```

## Next Steps

- [Add Web Search](/guides/web-search) - Enable AI-powered internet search
- [Choose Models](/guides/model-selection) - Find the best model for your task
- [Manage Models](/tools/ollama-manager) - Use the TUI for easy model management

## Troubleshooting

### "CUDA not available"
Ensure NVIDIA drivers are installed and up to date:
```powershell
nvidia-smi
```

### Models download slowly
Ollama downloads from their CDN. Large models (70B+) can take 30+ minutes on slower connections. Consider running downloads overnight.

### Out of memory errors
Your GPU VRAM is full. Either:
- Use a smaller quantization (q4 instead of q8)
- Use a smaller model
- Unload other models: `ollama stop <model-name>`
