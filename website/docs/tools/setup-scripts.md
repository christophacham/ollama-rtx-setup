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
| `optimize-ollama-5090.ps1` | Ensure models run 100% on GPU, cleanup duplicates |
| `update-pal-config.ps1` | Sync PAL MCP config with Ollama models |
| `setup-uncensored-models.ps1` | Download uncensored/unfiltered models |
| `limit-ollama-bandwidth.ps1` | Limit download bandwidth (requires Admin) |
| `scan-ollama-models.ps1` | Scan Ollama library for new coder models |
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

# Minimal models only (qwen2.5-coder:32b)
.\setup-ollama.ps1 -MinimalModels

# All recommended models (including community finetunes)
.\setup-ollama.ps1 -AllModels

# Coding-focused models only (10 models)
.\setup-ollama.ps1 -CoderModels

# Skip model downloads
.\setup-ollama.ps1 -SkipModels

# List available models without installing
.\setup-ollama.ps1 -ListModels
```

### Coder Models (-CoderModels)

The `-CoderModels` flag installs 10 coding-focused models:

| Model | Size | Description |
|-------|------|-------------|
| qwen2.5-coder:32b | ~19GB | Best local coding model |
| qwen3-coder:30b | ~19GB | 256K context MoE |
| devstral-small-2 | ~15GB | 384K context, 65.8% SWE-Bench |
| devstral | ~14GB | Agentic coding |
| mikepfunk28/deepseekq3_coder | ~5GB | DeepSeek + Qwen3 thinking |
| mikepfunk28/deepseekq3_agent | ~5GB | Agent-focused with tools |
| second_constantine/deepseek-coder-v2:16b | ~9GB | 160K MoE coder |
| qwen2.5-coder:14b | ~9GB | Efficient coding |
| deepseek-coder:33b | ~19GB | 87 language support |
| codellama:34b | ~20GB | Meta's coding model |

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
| qwen2.5:3b | ~4GB | Fast web search queries |
| qwen2.5-coder:14b | ~17GB | Synthesis and code |

**Total: ~21GB** - both models fit in VRAM simultaneously, leaving ~11GB for context.

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

| Service | Port | Notes |
|---------|------|-------|
| Open WebUI | 3000 | Chat interface |
| SearXNG | 4000 | Always started with Open WebUI |
| Perplexica Frontend | 3002 | (if installed) |
| Perplexica Backend | 3001 | (if installed) |

## optimize-ollama-5090.ps1

Ensures Ollama models run 100% on GPU with 0% CPU offloading. Optimized for RTX 5090 (32GB VRAM). Also includes cleanup to remove duplicate models.

### The Problem

Large models with default context windows overflow VRAM, causing CPU offloading:

```
ollama ps
NAME              ID            SIZE     PROCESSOR        UNTIL
deepseek-r1:32b   6e4c38e2f...  67 GB    61%/39% CPU/GPU  4 minutes from now
```

The "61%/39% CPU/GPU" means 61% of model layers are on CPU - slow!

### Usage

```powershell
# Optimize all installed models
.\optimize-ollama-5090.ps1

# Optimize a specific model
.\optimize-ollama-5090.ps1 -Model "deepseek-r1:32b"

# Show optimization status
.\optimize-ollama-5090.ps1 -List

# Remove all -5090 variants
.\optimize-ollama-5090.ps1 -Undo

# Override context size
.\optimize-ollama-5090.ps1 -ContextSize 32768

# Force re-optimize even if variant exists
.\optimize-ollama-5090.ps1 -Force

# Delete original models where -5090 variant exists (saves 100GB+)
.\optimize-ollama-5090.ps1 -Cleanup

# Auto-delete without prompting
.\optimize-ollama-5090.ps1 -Cleanup -NoPrompt

# Delete original immediately after each optimization
.\optimize-ollama-5090.ps1 -DeleteOriginal
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-Model` | Optimize a specific model instead of all |
| `-List` | Show optimization status without changes |
| `-Undo` | Remove all -5090 variants |
| `-Cleanup` | Delete originals where -5090 exists |
| `-DeleteOriginal` | Delete original after each successful optimization |
| `-NoPrompt` | Skip confirmation prompts (auto-yes) |
| `-ContextSize` | Override auto-calculated context size |
| `-Force` | Re-optimize even if variant exists |

### How It Works

1. **Test Each Model**: Loads model with a simple prompt, checks `ollama ps`
2. **Detect CPU Usage**: Parses processor column for CPU/GPU split
3. **Create Variant**: If CPU > 0%, creates `<model>-5090` variant with:
   - `num_gpu 99` - force all layers to GPU
   - Calculated `num_ctx` - reduced context to fit in VRAM
4. **Verify**: Re-tests the new variant to confirm 100% GPU
5. **Track**: Saves results to `5090-optimized.json`

### Context Size by Model

| Model Size | num_ctx | Reasoning |
|------------|---------|-----------|
| < 10GB | 65536 | Plenty of headroom |
| 10-15GB | 32768 | Good balance |
| 15-20GB | 16384 | Tight fit, prioritize GPU |
| > 20GB | 8192 | Minimal context, full GPU |

### Example Output

```
============================================================
  Ollama GPU Optimizer for RTX 5090 (32GB VRAM)
============================================================

[INFO] Detected GPU with 32GB VRAM
[INFO] Found 15 model(s) to test

Testing deepseek-r1:32b (19GB)...
  Loading model...
  CPU: 61% / GPU: 39% - NEEDS OPTIMIZATION
  Creating deepseek-r1:32b-5090 with num_ctx=16384, num_gpu=99
  Re-test: CPU: 0% / GPU: 100% - OK

Testing qwen3:32b (20GB)...
  Loading model...
  CPU: 0% / GPU: 100% - ALREADY OPTIMIZED

============================================================
  Summary
============================================================

  Tested:            15 model(s)
  Newly optimized:   8
  Already optimized: 7

[OK] Created 8 optimized variant(s)

Usage:
  ollama run <model>-5090
  Example: ollama run deepseek-r1:32b-5090
```

### Using Optimized Models

After optimization, use the `-5090` variants:

```powershell
# Instead of:
ollama run deepseek-r1:32b

# Use:
ollama run deepseek-r1:32b-5090
```

:::tip Recommended
Run this script after installing new models to ensure they're optimized for your GPU.
:::

### Cleanup Duplicate Models

After optimization, you have both the original and the `-5090` variant. The cleanup feature helps you reclaim storage:

```powershell
# See what can be cleaned up
.\optimize-ollama-5090.ps1 -List

# Delete originals where -5090 exists
.\optimize-ollama-5090.ps1 -Cleanup
```

**Example output:**

```
Found 10 base model(s) with existing -5090 variants:

  qwen3-coder:30b                             18 GB
  nemotron-3-nano:30b                         24 GB
  deepseek-r1:32b                             19 GB
  qwen2.5-coder:32b                           19 GB
  ...

Total space to free: 147.4 GB

Delete these 10 original model(s)? [y/N]
```

:::warning
Once deleted, originals cannot be recovered. You'll need to re-download them if needed. The `-5090` variants work identically but with optimized settings.
:::

## update-pal-config.ps1

Synchronizes your [PAL MCP Server](https://github.com/BeehiveInnovations/pal-mcp-server) configuration with locally installed Ollama models. PAL is an AI orchestration tool that provides advanced capabilities like multi-model consensus, deep thinking, and systematic code review.

### Why Use This Script

When you install or optimize Ollama models, PAL doesn't automatically know about them. This script:

1. **Discovers your models** - Scans `ollama list` for all installed models
2. **Sets capabilities** - Marks reasoning models with `supports_extended_thinking`
3. **Ranks models** - Assigns `intelligence_score` for model selection
4. **Creates aliases** - Short names like `r1` → `deepseek-r1:32b-5090`
5. **Recommends tools** - Shows which models work best for which PAL tools

### Usage

```powershell
# Compare current PAL config vs installed models (dry-run)
.\update-pal-config.ps1 -List

# Update PAL config (prompts for confirmation)
.\update-pal-config.ps1

# Prefer -5090 optimized variants (recommended)
.\update-pal-config.ps1 -Prefer5090

# Auto-update without prompting
.\update-pal-config.ps1 -Prefer5090 -NoPrompt

# Specify custom PAL config path
.\update-pal-config.ps1 -PalConfigPath "D:\pal-mcp-server\conf\custom_models.json"
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-List` | Compare config vs installed models without changes |
| `-Prefer5090` | Only include -5090 variants when both exist |
| `-NoPrompt` | Skip confirmation prompts |
| `-PalConfigPath` | Custom path to custom_models.json |

### Example Output

```
============================================================
  PAL MCP Server Config Updater
============================================================

[INFO] PAL config: C:\Users\...\pal-mcp-server\conf\custom_models.json
[INFO] Found 26 Ollama model(s)

======================================================================
  PAL Config vs Ollama Models Comparison
======================================================================

Models in Ollama NOT in PAL config:
  + deepseek-r1:32b-5090 [5090]
  + qwen2.5-coder:32b-5090 [5090]
  + qwen3:32b-5090 [5090]
  ...

======================================================================
  Recommended Models for PAL Tools
======================================================================

THINKDEEP / CHALLENGE (reasoning, extended thinking):
  * deepseek-r1:32b-5090 (score: 18)
    qwen3:32b-5090 (score: 17)
    qwen3-coder:30b-5090 (score: 17)

CONSENSUS (multi-model debate, diverse perspectives):
  Suggested consensus panel:
    - deepseek-r1:32b-5090 (for)
    - qwen2.5-coder:32b-5090 (against)
    - qwen3:32b-5090 (neutral)

CODEREVIEW / DEBUG / REFACTOR (coding analysis):
  * qwen2.5-coder:32b-5090 (score: 18)
    qwen2.5-coder:14b (score: 18)
    qwen3-coder:30b-5090 (score: 17)

CHAT / QUICK QUERIES (fast responses):
  * llama3.1:8b-5090
  * mistral:7b
  * qwen2.5:3b

* = recommended for this tool category
```

### Model Capabilities Set

The script sets these fields based on model type:

| Model Pattern | `supports_extended_thinking` | `intelligence_score` |
|---------------|------------------------------|----------------------|
| deepseek-r1 | ✅ true | 18 |
| qwen3 | ✅ true | 17 |
| nemotron | ✅ true | 16 |
| phi4 | ✅ true | 16 |
| qwen2.5-coder | ❌ false | 18 |
| devstral | ❌ false | 16-17 |
| llama3.1:8b | ❌ false | 12 |
| mistral:7b | ❌ false | 10 |

### Tool Recommendations

| PAL Tool | Best For | Recommended Models |
|----------|----------|-------------------|
| **thinkdeep** | Deep reasoning, complex analysis | deepseek-r1, qwen3, nemotron |
| **challenge** | Question assumptions, find flaws | deepseek-r1, qwen3 |
| **consensus** | Multi-model debate | Mix of reasoning + coding |
| **codereview** | Systematic code analysis | qwen2.5-coder, devstral |
| **debug** | Root cause investigation | qwen2.5-coder, deepseek-r1 |
| **refactor** | Code improvement | qwen2.5-coder, qwen3-coder |
| **chat** | Quick queries | llama3.1:8b, mistral:7b |

### Workflow

Typical workflow after installing new models:

```powershell
# 1. Download new models
ollama pull qwen3-coder:30b

# 2. Optimize for GPU
.\optimize-ollama-5090.ps1 -Model "qwen3-coder:30b"

# 3. Clean up original
.\optimize-ollama-5090.ps1 -Cleanup

# 4. Update PAL config
.\update-pal-config.ps1 -Prefer5090

# 5. Restart Claude Desktop to apply
```

:::tip
Use `-Prefer5090` to ensure PAL uses your GPU-optimized variants instead of the originals.
:::

## limit-ollama-bandwidth.ps1

Limits Ollama download bandwidth to prevent network saturation. **Requires Administrator privileges.**

### Usage

```powershell
# Interactive menu (prompts for action)
.\limit-ollama-bandwidth.ps1

# Limit to 50% of tested speed
.\limit-ollama-bandwidth.ps1 -Limit

# Limit to 30% of tested speed
.\limit-ollama-bandwidth.ps1 -Limit -Percent 30

# Remove bandwidth limit
.\limit-ollama-bandwidth.ps1 -Unlimit

# Skip speed test, use manual value
.\limit-ollama-bandwidth.ps1 -Limit -SkipSpeedTest -SpeedMbps 100
```

### How It Works

1. **Speed Test**: Downloads a test file to measure your connection speed
2. **Calculate Limit**: Computes the target bandwidth (default: 50%)
3. **Apply QoS Policy**: Creates a Windows QoS policy to throttle `ollama.exe`
4. **Cleanup**: Use `-Unlimit` to remove the policy when done

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-Limit` | Enable bandwidth limiting |
| `-Unlimit` | Remove bandwidth limiting |
| `-Percent` | Percentage of bandwidth to allow (default: 50) |
| `-SkipSpeedTest` | Skip speed test, use `-SpeedMbps` value |
| `-SpeedMbps` | Manual speed in Mbps (use with `-SkipSpeedTest`) |

:::tip Recommended Workflow
1. Run `-Limit` before downloading large models
2. Run your `setup-ollama.ps1 -AllModels` or `ollama pull` commands
3. Run `-Unlimit` when downloads are complete
:::

:::note Alternative
If you don't have Admin rights, set the environment variable instead:
```powershell
$env:OLLAMA_DOWNLOAD_CONN = 1
```
This limits to a single download connection (fair share with other traffic).
:::

## scan-ollama-models.ps1

Scans Ollama library for new coder models not in your configuration.

### Usage

```powershell
# Scan for new models with >100 pulls
.\scan-ollama-models.ps1

# Lower threshold to find more models
.\scan-ollama-models.ps1 -MinPulls 50

# Save results to JSON report
.\scan-ollama-models.ps1 -SaveReport

# Check for updates to existing models
.\scan-ollama-models.ps1 -CheckUpdates
```

### How It Works

Since Ollama doesn't have a public browse API, the script maintains a **watchlist** of known quality model namespaces:

| Type | Namespaces |
|------|------------|
| Official | qwen2.5-coder, qwen3-coder, deepseek-coder, codellama, devstral, gpt-oss |
| Community | NeuralNexusLab/CodeXor, mikepfunk28/deepseekq3, mannix/qwen2.5-coder |

The script:
1. Queries each namespace on Ollama's website
2. Extracts pull counts and update dates
3. Compares against your `custom_models.json`
4. Reports new models above the pull threshold

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-MinPulls` | Minimum pull count to consider (default: 100) |
| `-ConfigPath` | Path to custom_models.json (default: ./custom_models.json) |
| `-CheckUpdates` | Also check if installed models have updates |
| `-SaveReport` | Save results to scan-report.json |

### Example Output

```
  Checking qwen2.5-coder... 150000 pulls, EXISTS
  Checking NeuralNexusLab/CodeXor... 134 pulls, NEW
  Checking mikepfunk28/deepseekq3... 50 pulls, EXISTS

New models meeting criteria (>= 100 pulls):
  NeuralNexusLab/CodeXor - 134 pulls, updated 2 days ago

To add these models:
  1. Add to $coderModels in setup-ollama.ps1
  2. Add entry to custom_models.json
  3. Run: ollama pull <model-name>
```

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
