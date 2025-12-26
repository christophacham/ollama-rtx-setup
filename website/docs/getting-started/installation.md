---
sidebar_position: 2
---

# Installation Guide

Detailed installation instructions for all components.

## System Requirements

### Operating System
- **Windows 10** (version 1903 or later) or **Windows 11**
- 64-bit only
- WSL2 optional (for Docker/Podman containers)

### Hardware

| Component | Minimum | Recommended | Optimal |
|-----------|---------|-------------|---------|
| **GPU** | RTX 3060 | RTX 4090 | RTX 5090 |
| **VRAM** | 12GB | 24GB | 32GB |
| **System RAM** | 16GB | 32GB | 64GB |
| **Storage** | 50GB SSD | 200GB NVMe | 500GB+ NVMe |
| **CPU** | Any modern | 8+ cores | 16+ cores |

### NVIDIA Driver Requirements

| CUDA Version | Minimum Driver | Recommended |
|--------------|----------------|-------------|
| CUDA 12.x | 525.60+ | 550.0+ |
| CUDA 11.x | 450.80+ | 470.0+ |

Check your driver version:
```powershell
nvidia-smi
```

## Installing Ollama

### Automatic Installation (Recommended)

```powershell
.\setup-ollama.ps1
```

This handles everything automatically.

### Manual Installation

1. Download from [ollama.ai](https://ollama.ai/download/windows)
2. Run the installer
3. Verify installation:
```powershell
ollama --version
```

### Environment Configuration

For container access, Ollama must listen on all interfaces:

```powershell
# Set environment variable
[Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "User")

# Restart Ollama
ollama serve
```

## Installing Docker or Podman

Required for Open WebUI and Perplexica.

### Docker Desktop (Easier)

1. Download [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Enable WSL2 backend during setup
3. Verify:
```powershell
docker info
```

### Podman (Lighter, Open Source)

```powershell
# Install via winget
winget install RedHat.Podman

# Initialize machine
podman machine init
podman machine start

# Verify
podman info
```

:::caution Podman Networking
Podman on WSL2 has networking quirks. See [Podman Networking](/architecture/network) for details.
:::

## Installing Web Search Components

### Open WebUI

```powershell
.\setup-ollama-websearch.ps1 -Setup OpenWebUI
```

Access at: http://localhost:3000

### Perplexica + SearXNG

```powershell
.\setup-ollama-websearch.ps1 -Setup Perplexica
```

Access at:
- Perplexica: http://localhost:3002
- SearXNG: http://localhost:4000

## Verifying Installation

Run the test suite:

```powershell
.\test-ollama-stack.ps1
```

Expected output:
```
[Prerequisites]
  [PASS] Podman is running
  [PASS] NVIDIA GPU detected (NVIDIA GeForce RTX 5090)

[Ollama]
  [PASS] API responding on :11434
  [PASS] 6 models available
  [PASS] Model loaded (qwen3:32b)

[Open WebUI]
  [PASS] Container running
  [PASS] Using CUDA image
  [PASS] UI accessible on :3000
```

## Uninstalling

### Remove Containers

```powershell
.\setup-ollama-websearch.ps1 -Uninstall
```

### Remove Ollama

1. Uninstall via Windows Settings → Apps
2. Delete model data:
```powershell
Remove-Item -Recurse "$env:USERPROFILE\.ollama"
```

### Remove Models Only

```powershell
# List models
ollama list

# Remove specific model
ollama rm qwen3:32b

# Remove all (keep Ollama)
Get-ChildItem "$env:USERPROFILE\.ollama\models\manifests" -Recurse | Remove-Item -Recurse
```
