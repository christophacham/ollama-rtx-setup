---
sidebar_position: 2
---

# Setup Scripts

PowerShell scripts for automated setup and management.

## Overview

| Script | Purpose |
|--------|---------|
| `setup-ollama.ps1` | Main Ollama installation and model setup |
| `setup-ollama-websearch.ps1` | Web search integration (Open WebUI, Perplexica) |
| `setup-uncensored-models.ps1` | Download uncensored/unfiltered models |
| `backup-ollama-models.ps1` | Backup/restore models to external storage |
| `debug-ollama-connection.ps1` | Diagnose container connectivity issues |
| `test-ollama-stack.ps1` | Test suite for verifying setup |
| `test-searxng-engines.ps1` | Test each SearXNG search engine individually |
| `cleanup-containers.ps1` | Stop and remove stack containers |
| `sync-container-images.ps1` | Mirror container images to your registry |

## setup-ollama.ps1

The main setup script for Ollama and models.

### Usage

```powershell
# Default: Install Ollama + recommended models
.\setup-ollama.ps1

# Minimal models only (7-8B)
.\setup-ollama.ps1 -MinimalModels

# All recommended models
.\setup-ollama.ps1 -AllModels

# Skip model downloads
.\setup-ollama.ps1 -SkipModels

# List available models without installing
.\setup-ollama.ps1 -ListModels
```

### What It Does

1. **Checks prerequisites** - NVIDIA drivers, GPU detection
2. **Installs Ollama** - Downloads and installs if not present
3. **Configures environment** - Sets `OLLAMA_HOST` for container access
4. **Downloads models** - Smart detection (only downloads missing models)
5. **Updates MCP config** - Configures `custom_models.json` for PAL

### Model Selection

Models are selected based on your VRAM:

| VRAM | Models |
|------|--------|
| 32GB+ | qwen3:32b, deepseek-r1:32b, llama3.3:70b-q4 |
| 24GB | qwen3:32b, deepseek-r1:32b, llama3.1:8b |
| 16GB | qwen3:14b, llama3.1:8b, mistral:7b |
| 12GB | llama3.1:8b, mistral:7b, phi-4:14b-q4 |

## setup-ollama-websearch.ps1

Installs web search integration with optimized models and integrated testing.

### Usage

```powershell
# Recommended: Single-user mode (no login required)
.\setup-ollama-websearch.ps1 -Setup OpenWebUI -SingleUser

# Interactive menu (prompts for choice)
.\setup-ollama-websearch.ps1

# Install Perplexica + SearXNG
.\setup-ollama-websearch.ps1 -Setup Perplexica

# Install both
.\setup-ollama-websearch.ps1 -Setup Both

# Skip model downloads
.\setup-ollama-websearch.ps1 -Setup OpenWebUI -SkipModels

# Use mirrored images from your registry
.\setup-ollama-websearch.ps1 -UseLocalRegistry

# Remove all web search containers
.\setup-ollama-websearch.ps1 -Uninstall
```

### Models Installed (RTX 5090 Optimized)

The script automatically pulls models optimized for 32GB VRAM:

| Model | VRAM | Purpose |
|-------|------|---------|
| qwen2.5:3b | ~2GB | Fast web search queries |
| qwen2.5:14b | ~8GB | Synthesis & aggregation |
| qwen2.5-coder:14b | ~8GB | Code generation |

**Total: ~18GB** leaving ~14GB for context windows.

### Integrated Testing

After installation, the script runs a 4-phase test:

| Phase | Test | Description |
|-------|------|-------------|
| 1 | Model inference | Each model responds to a prompt |
| 2 | SearXNG check | Verifies search engine returns results |
| 3 | Web context | Model processes search results |
| 4 | Log check | Open WebUI shows web search activity |

### Container Runtime Detection

Automatically detects Docker or Podman:

```powershell
# Preferred order:
# 1. Docker (if running)
# 2. Podman (if running)
```

### Ports Used

| Service | Port |
|---------|------|
| Open WebUI | 3000 |
| Perplexica Frontend | 3002 |
| Perplexica Backend | 3001 |
| SearXNG | 4000 |

## setup-uncensored-models.ps1

Downloads uncensored/unfiltered models for unrestricted conversations.

### Usage

```powershell
# Install uncensored models
.\setup-uncensored-models.ps1

# Force re-download all
.\setup-uncensored-models.ps1 -Force
```

### Models Installed

| Model | Author | Focus |
|-------|--------|-------|
| dolphin-mistral:7b | Eric Hartford | General uncensored |
| wizard-vicuna-uncensored:13b | Community | Instruction following |
| llama2-uncensored:7b | George Sung | Base uncensored |
| dolphin-phi:2.7b | Eric Hartford | Small uncensored |

:::warning Use Responsibly
Uncensored models lack safety guardrails. Use for legitimate purposes only.
:::

## backup-ollama-models.ps1

Backup and restore models to/from external storage.

### Usage

```powershell
# Show current status
.\backup-ollama-models.ps1 -Info

# Backup to external drive
.\backup-ollama-models.ps1 -Backup -Destination "E:\ollama-backup"

# Restore from backup
.\backup-ollama-models.ps1 -Restore -Source "E:\ollama-backup"
```

### Features

- **Robocopy** - Reliable large file transfer
- **Auto-stop** - Stops Ollama before operations
- **Space check** - Verifies disk space before backup
- **Incremental** - Only copies changed files

See [Backup & Restore Guide](/guides/backup-restore) for details.

## debug-ollama-connection.ps1

Diagnoses and fixes container-to-Ollama connectivity issues.

### Usage

```powershell
# Diagnose only (no changes)
.\debug-ollama-connection.ps1

# Diagnose and fix automatically
.\debug-ollama-connection.ps1 -Fix

# Debug a different container
.\debug-ollama-connection.ps1 -Container perplexica-backend -Fix
```

### Diagnostic Phases

1. **Host Check** - Is Ollama running on Windows?
2. **Container Check** - Is container running? Checks restart count, health status, shows logs on issues
3. **Connectivity Test** - Can container reach Ollama?
4. **Gateway Discovery** - Auto-detect correct IP for Podman
5. **Analysis** - Explain the problem
6. **Fix** - Recreate container with correct settings

### Features

- **Restart loop detection** - Warns if container has restarted >3 times
- **Health status check** - Reports container health (healthy/unhealthy)
- **Auto-show logs** - Displays recent logs when issues detected
- **Gateway auto-detect** - Finds Podman gateway IP automatically

See [Podman Troubleshooting](/troubleshooting/podman-ollama) for details.

## test-ollama-stack.ps1

Comprehensive test suite for verifying your setup.

### Usage

```powershell
# Standard tests
.\test-ollama-stack.ps1

# Include inference tests (slower)
.\test-ollama-stack.ps1 -Full

# Output as JSON (for CI)
.\test-ollama-stack.ps1 -Json
```

### What's Tested

| Category | Tests |
|----------|-------|
| Prerequisites | Container runtime, NVIDIA GPU |
| Ollama | API, models, GPU acceleration |
| Open WebUI | Container health, restart loops, image tag, UI access |
| Perplexica | SearXNG, backend, frontend (health status for each) |

### Health Checks

The test suite detects:
- **Restart loops** - Fails if container has restarted >3 times
- **Health status** - Reports healthy/unhealthy/starting
- **Auto-show logs** - Displays recent logs on failures

### Example Output

```
========================================
  Ollama Stack Test Suite
========================================

[Prerequisites]
  [PASS] Podman is running
  [PASS] NVIDIA GPU detected (GeForce RTX 5090)

[Ollama]
  [PASS] API responding on :11434
  [PASS] 6 models available
  [SKIP] No models currently loaded
  [SKIP] Inference test (use -Full flag)

[Open WebUI]
  [PASS] Container running (health: healthy)
  [PASS] Using CUDA image (no embedded Ollama)
  [PASS] UI accessible on :3000

[Perplexica]
  [PASS] SearXNG container running (health: healthy)
  [PASS] SearXNG accessible on :4000
  [PASS] Backend container running
  [PASS] Frontend container running
  [PASS] Frontend accessible on :3002

========================================
  Results: 12 passed, 0 failed, 2 skipped
========================================
```

## sync-container-images.ps1

Mirrors container images to your own GitHub Container Registry.

### Usage

```powershell
# Check for updates (no changes)
.\sync-container-images.ps1

# Sync changed images
.\sync-container-images.ps1 -Sync

# Force sync all
.\sync-container-images.ps1 -Force

# Sync specific image
.\sync-container-images.ps1 -Sync -Image "open-webui:cuda"
```

### Images Tracked

| Image | Upstream |
|-------|----------|
| open-webui:cuda | ghcr.io/open-webui/open-webui:cuda |
| open-webui:main | ghcr.io/open-webui/open-webui:main |
| searxng:latest | docker.io/searxng/searxng:latest |
| perplexica-backend:main | docker.io/itzcrazykns1337/perplexica-backend:main |
| perplexica-frontend:main | docker.io/itzcrazykns1337/perplexica-frontend:main |

See [Container Sync](/tools/container-sync) for details.

## cleanup-containers.ps1

Stop and remove all Ollama stack containers.

### Usage

```powershell
# Interactive - asks what to delete
.\cleanup-containers.ps1

# Remove containers only (keep data)
.\cleanup-containers.ps1 -Force

# Remove containers AND volumes (deletes all data)
.\cleanup-containers.ps1 -DeleteVolumes

# Remove everything, no prompts
.\cleanup-containers.ps1 -DeleteVolumes -Force
```

### What It Removes

| Container | Data Location |
|-----------|---------------|
| open-webui | `open-webui` volume |
| perplexica-frontend | - |
| perplexica-backend | `./perplexica/data` |
| searxng | `./searxng` |

### Options

| Parameter | Description |
|-----------|-------------|
| `-Force` | Skip confirmation prompts |
| `-DeleteVolumes` | Also remove volumes (persistent data) |

## Common Parameters

### Verbose Output

Most scripts support verbose logging:

```powershell
.\setup-ollama.ps1 -Verbose
```

### What-If Mode

Some scripts support dry-run:

```powershell
.\backup-ollama-models.ps1 -Backup -WhatIf
```

### Help

All scripts include help:

```powershell
Get-Help .\setup-ollama.ps1 -Full
```

Or use the comment-based help at the top of each script.
