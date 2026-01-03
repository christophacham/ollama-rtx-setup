# Complete Setup Guide: Claude Desktop, Codex CLI, Gemini CLI, and Copilot CLI with PAL MCP

This document provides a comprehensive guide for setting up all four AI CLIs (Claude Desktop, Codex CLI, Gemini CLI, and GitHub Copilot CLI) to work with PAL MCP Server using a shared conda environment and local Ollama models.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Shared Conda Environment Setup](#shared-conda-environment-setup)
4. [Claude Desktop Configuration](#claude-desktop-configuration)
5. [Codex CLI Configuration](#codex-cli-configuration)
6. [Gemini CLI Configuration](#gemini-cli-configuration)
7. [Copilot CLI Configuration](#copilot-cli-configuration)
8. [Configuration Files Reference](#configuration-files-reference)
9. [Verification & Testing](#verification--testing)
10. [Troubleshooting](#troubleshooting)
11. [Issues Fixed During Setup](#issues-fixed-during-setup)

---

## Overview

This setup enables **four AI CLIs** to orchestrate your local Ollama models through a **single PAL MCP Server instance** running in a **shared conda environment**.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Shared Conda Environment                   │
│                        (pal-mcp)                             │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              PAL MCP Server                         │    │
│  │         (Multi-model orchestration)                 │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↓                                   │
│                    Ollama Server                             │
│                  (localhost:11434)                           │
│                          ↓                                   │
│     ┌────────────────────────────────────────────┐          │
│     │  Local Models (RTX 5090 - 32GB VRAM)      │          │
│     │  • qwen2.5-coder:32b-5090                 │          │
│     │  • deepseek-r1:32b-5090                   │          │
│     │  • qwen3:32b-5090                         │          │
│     │  • ... and more                            │          │
│     └────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
         ↑              ↑              ↑              ↑
    Claude Desktop  Codex CLI    Gemini CLI    Copilot CLI
    (Browser UI)    (Terminal)   (Terminal)    (Terminal)
```

### Why This Setup?

| Benefit | Description |
|---------|-------------|
| **Environment Isolation** | All dependencies in one conda env, no conflicts |
| **Resource Efficiency** | One PAL instance serves all three CLIs |
| **Consistent Config** | Same Ollama models available everywhere |
| **Easy Updates** | Update conda env once, affects all CLIs |
| **100% Local** | No API keys needed, complete privacy |

---

## Prerequisites

### Required Software

1. **Anaconda or Miniconda**
   ```powershell
   # Download from: https://www.anaconda.com/download
   conda --version  # Verify installation
   ```

2. **Ollama** (with models installed)
   ```powershell
   ollama --version
   ollama list  # Should show your installed models
   ```

3. **PAL MCP Server** (cloned locally)
   ```powershell
   git clone https://github.com/BeehiveInnovations/pal-mcp-server
   cd pal-mcp-server
   ```

4. **Node.js & npm** (for Codex and Gemini CLIs)
   ```powershell
   node --version  # v18+ recommended
   npm --version
   ```

### Optional (but recommended)

- **Claude Desktop** - Download from https://claude.ai/download
- **Codex CLI** - Install via npm (covered below)
- **Gemini CLI** - Install via npm (covered below)

---

## Shared Conda Environment Setup

This conda environment will be used by **all three CLIs**.

### Step 1: Create the Environment

```powershell
# Create conda environment
conda create -n pal-mcp python=3.11 -y

# Activate it
conda activate pal-mcp
```

### Step 2: Install Dependencies

```powershell
# Install required packages
pip install anthropic openai google-generativeai requests mcp

# Verify installation
python -c "import anthropic; import openai; print('Dependencies installed!')"
```

### Step 3: Configure PAL MCP Server

Navigate to your PAL MCP Server directory:

```powershell
cd C:\Users\Egusto\code\pal-mcp-server
```

Create or update `.env` file:

```bash
# Local Ollama (no API key needed!)
CUSTOM_API_URL=http://localhost:11434/v1
OLLAMA_BASE_URL=http://localhost:11434
DEFAULT_MODEL=auto

# Optional: Add cloud providers if desired
# OPENAI_API_KEY=sk-...
# GEMINI_API_KEY=...
```

**Test the server manually:**

```powershell
# Activate conda env
conda activate pal-mcp

# Start server
python server.py

# Should see: "PAL MCP Server started on stdio..."
# Press Ctrl+C to stop
```

---

## Claude Desktop Configuration

Claude Desktop uses a JSON config file to configure MCP servers.

### Configuration File Location

```
%APPDATA%\Claude\claude_desktop_config.json
```

Full path example:
```
C:\Users\Egusto\AppData\Roaming\Claude\claude_desktop_config.json
```

### Configuration Content

```json
{
  "mcpServers": {
    "pal": {
      "command": "C:\\Users\\Egusto\\anaconda3\\condabin\\conda.bat",
      "args": [
        "run",
        "-n",
        "pal-mcp",
        "--no-capture-output",
        "python",
        "C:\\Users\\Egusto\\code\\pal-mcp-server\\server.py"
      ]
    }
  }
}
```

### Setup Steps

1. **Create the directory if it doesn't exist:**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:APPDATA\Claude"
   ```

2. **Create or edit the config file:**
   ```powershell
   notepad "$env:APPDATA\Claude\claude_desktop_config.json"
   ```

3. **Paste the configuration above** (update paths for your username)

4. **Restart Claude Desktop** for changes to take effect

### Verification

1. Open Claude Desktop
2. Check the bottom-right corner for MCP server status
3. Should see "pal" server listed and connected
4. Test with: "Use pal to list available models"

---

## Codex CLI Configuration

Codex CLI is OpenAI's command-line interface that supports local models via Ollama and MCP servers.

### Installation

```powershell
# Install globally via npm
npm install -g @openai/codex-cli

# Verify installation
codex --version
# Output: codex-cli 0.77.0
```

### Configuration File Location

```
C:\Users\Egusto\.codex\config.toml
```

### Configuration Content

Create `~/.codex/config.toml` with the following content:

```toml
# Codex CLI Configuration for Windows + Conda
# Location: C:\Users\Egusto\.codex\config.toml

# ============================================
# Model Providers Configuration
# ============================================

[model_providers.ollama]
name = "Ollama"
base_url = "http://localhost:11434/v1"
wire_api = "responses"  # Fixes deprecation warning (NOT "chat")

# ============================================
# Model Profiles
# ============================================

[profiles.qwen-code]
model_provider = "ollama"
model = "qwen2.5-coder:32b-5090"

[profiles.deepseek]
model_provider = "ollama"
model = "deepseek-r1:32b-5090"

[profiles.fast]
model_provider = "ollama"
model = "qwen2.5:3b"

[profiles.medium]
model_provider = "ollama"
model = "qwen2.5-coder:14b"

# ============================================
# MCP Servers Configuration - Using Conda
# ============================================

[mcp_servers.pal]
command = "C:\\Users\\Egusto\\anaconda3\\condabin\\conda.bat"
args = [
    "run",
    "-n",
    "pal-mcp",
    "--no-capture-output",
    "python",
    "C:\\Users\\Egusto\\code\\pal-mcp-server\\server.py"
]

# Timeouts - from official PAL guide
startup_timeout_sec = 300   # 5 minutes for conda env activation
tool_timeout_sec = 1200      # 20 minutes for PAL tool execution

[mcp_servers.pal.env]
OLLAMA_BASE_URL = "http://localhost:11434"
DEFAULT_MODEL = "auto"

# ============================================
# Features Configuration
# ============================================

[features]
web_search_request = true  # Enable web search for PAL's apilookup

# ============================================
# Default Settings
# ============================================

[defaults]
provider = "ollama"
model = "qwen2.5-coder:32b-5090"
```

### Setup Steps

1. **Create the .codex directory:**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.codex"
   ```

2. **Copy the template config:**
   ```powershell
   # From this repo
   cd C:\Users\Egusto\code\ollama-rtx-setup
   Copy-Item codex-config-conda.toml "$env:USERPROFILE\.codex\config.toml"
   ```

3. **Verify the paths match your setup** (should already be correct)

### Verification

```powershell
# Launch Codex
codex

# Check MCP servers
/mcp

# Should show:
# • pal
#   • Status: enabled
#   • Tools: analyze, apilookup, challenge, chat, clink, codereview, consensus,
#            debug, docgen, listmodels, planner, precommit, refactor, secaudit,
#            testgen, thinkdeep, tracer, version
```

### Usage Examples

```powershell
# Default model
codex
> Write a Python function to parse JSON

# Quick queries
codex -p fast
> What's new in Python 3.13?

# Deep reasoning
codex -p deepseek
> Debug this memory leak step by step

# PAL integration
codex
> Use pal thinkdeep to analyze this algorithm
> Use pal consensus with fast and deepseek to evaluate this design
```

---

## Gemini CLI Configuration

Gemini CLI is Google's command-line interface that supports MCP servers.

### Installation

```powershell
# Install globally via npm
npm install -g @google/generative-ai-cli

# Verify installation
gemini --version
# Output: 0.22.5
```

### Configuration File Location

```
C:\Users\Egusto\.gemini\settings.json
```

### Configuration Content

Create `~/.gemini/settings.json` with the following content:

```json
{
  "mcpServers": {
    "pal": {
      "command": "C:\\Users\\Egusto\\anaconda3\\condabin\\conda.bat",
      "args": [
        "run",
        "-n",
        "pal-mcp",
        "--no-capture-output",
        "python",
        "C:\\Users\\Egusto\\code\\pal-mcp-server\\server.py"
      ],
      "env": {
        "OLLAMA_BASE_URL": "http://localhost:11434",
        "DEFAULT_MODEL": "auto"
      }
    }
  },
  "security": {
    "auth": {
      "selectedType": "oauth-personal"
    }
  }
}
```

### Setup Steps

1. **First run (creates config directory):**
   ```powershell
   gemini --version
   # This creates ~/.gemini/ directory
   ```

2. **Copy the template config:**
   ```powershell
   # From this repo
   cd C:\Users\Egusto\code\ollama-rtx-setup
   Copy-Item gemini-settings.json "$env:USERPROFILE\.gemini\settings.json" -Force
   ```

3. **Verify the paths match your setup** (should already be correct)

### Verification

```powershell
# Check MCP servers
gemini mcp list

# Should show:
# Configured MCP servers:
# ✗ pal: C:\Users\Egusto\anaconda3\condabin\conda.bat run -n pal-mcp ...
#        (stdio) - Disconnected
#        ^ This is normal - connects when used

# Launch Gemini
gemini

# Test PAL integration
> Use pal to list available models
```

### Usage Examples

```powershell
# Interactive mode
gemini
> Use pal thinkdeep to analyze this code

# Non-interactive
gemini "Write a Rust function to handle HTTP requests"

# With specific Gemini model
gemini -m gemini-2.5-pro "Explain async programming"
```

---

## Copilot CLI Configuration

GitHub Copilot CLI is GitHub's command-line AI assistant that supports MCP servers for extended functionality.

### Installation

```powershell
# Install globally via npm
npm install -g @github/copilot

# Verify installation
copilot --version
# Output: 0.0.374
```

### Configuration File Location

```
C:\Users\Egusto\.copilot\mcp-config.json
```

### Method A: Conda Configuration (Recommended)

Create `~/.copilot/mcp-config.json` with the following content:

```json
{
  "mcpServers": {
    "pal": {
      "type": "local",
      "command": "C:\\Users\\Egusto\\anaconda3\\condabin\\conda.bat",
      "tools": ["*"],
      "args": [
        "run",
        "-n",
        "pal-mcp",
        "--no-capture-output",
        "python",
        "C:\\Users\\Egusto\\code\\pal-mcp-server\\server.py"
      ],
      "env": {
        "OLLAMA_BASE_URL": "http://localhost:11434",
        "DEFAULT_MODEL": "auto"
      }
    }
  }
}
```

### Method B: Virtual Environment Configuration

For users without conda, use the venv approach:

```json
{
  "mcpServers": {
    "pal": {
      "type": "local",
      "command": "C:\\Users\\Egusto\\code\\pal-mcp-server\\.pal_venv\\Scripts\\python.exe",
      "tools": ["*"],
      "args": [
        "C:\\Users\\Egusto\\code\\pal-mcp-server\\server.py"
      ],
      "env": {
        "OLLAMA_BASE_URL": "http://localhost:11434",
        "DEFAULT_MODEL": "auto"
      }
    }
  }
}
```

### Key Configuration Notes

**Important:** Copilot CLI MCP config requires:

1. **`"type": "local"`** - Specifies this is a local command (not HTTP/SSE)
2. **`"tools": ["*"]`** - **REQUIRED!** Must specify which tools to enable (`["*"]` for all)
3. **`"command"`** - The executable to run
4. **`"args"`** - Arguments passed to the command

**Common Error:** If you forget `"tools": ["*"]`, you'll get:
```
Failed to start MCP Servers: ... "tools" ... "message": "Required"
```

### Setup Steps

1. **Create the .copilot directory (if needed):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.copilot"
   ```

2. **Copy the template config:**
   ```powershell
   # From this repo (choose one):
   cd C:\Users\Egusto\code\ollama-rtx-setup

   # For conda users:
   Copy-Item copilot-mcp-config-conda.json "$env:USERPROFILE\.copilot\mcp-config.json"

   # For venv users:
   Copy-Item copilot-mcp-config-venv.json "$env:USERPROFILE\.copilot\mcp-config.json"
   ```

3. **Verify the paths match your setup** (should already be correct)

### Verification

```powershell
# Launch Copilot CLI
copilot

# Should show:
# ● Configured MCP servers: pal
# ● Connected to GitHub MCP Server
```

### Usage Examples

```powershell
# Interactive mode
copilot
> Use pal to list available models

# Allow PAL tools without prompting
copilot --allow-tool 'pal'
> Use pal thinkdeep to analyze this code

# Non-interactive with tool approval
copilot -p "Use pal codereview to review main.py" --allow-tool 'pal'

# YOLO mode (auto-approve all tools)
copilot --allow-all-tools
> Use pal consensus with fast and deepseek to evaluate this API

# With specific model
copilot --model claude-opus-4.5
> Use pal to debug this memory issue
```

### Available Models in Copilot CLI

| Model | Provider | Best For |
|-------|----------|----------|
| `gpt-5.1-codex-max` | OpenAI | Best coding (default) |
| `gpt-5.1-codex` | OpenAI | Fast coding |
| `gpt-5.2` | OpenAI | Latest GPT |
| `claude-opus-4.5` | Anthropic | Complex reasoning |
| `claude-sonnet-4.5` | Anthropic | Balanced |
| `gemini-3-pro-preview` | Google | Google's latest |

### Tool Approval Options

| Flag | Effect |
|------|--------|
| `--allow-tool 'pal'` | Auto-approve all PAL tools |
| `--allow-tool 'pal(thinkdeep)'` | Auto-approve only thinkdeep |
| `--deny-tool 'pal(secaudit)'` | Block specific tool |
| `--allow-all-tools` | Auto-approve everything (YOLO) |

---

## Configuration Files Reference

### File Locations Summary

| CLI | Config File | Location |
|-----|-------------|----------|
| **Claude Desktop** | `claude_desktop_config.json` | `%APPDATA%\Claude\` |
| **Codex CLI** | `config.toml` | `~/.codex/` |
| **Gemini CLI** | `settings.json` | `~/.gemini/` |
| **Copilot CLI** | `mcp-config.json` | `~/.copilot/` |

### Shared Configuration Elements

All four configs use the **same conda command**:

```
Command: C:\Users\Egusto\anaconda3\condabin\conda.bat
Args: run -n pal-mcp --no-capture-output python C:\Users\Egusto\code\pal-mcp-server\server.py
```

**Key parameters explained:**

| Parameter | Purpose |
|-----------|---------|
| `conda.bat` | Windows conda wrapper (handles environment activation) |
| `run -n pal-mcp` | Run command in pal-mcp environment |
| `--no-capture-output` | Stream output immediately (better for debugging) |
| `python server.py` | Execute PAL MCP Server |

### Environment Variables

Passed to PAL MCP Server:

```
OLLAMA_BASE_URL=http://localhost:11434
DEFAULT_MODEL=auto
```

**What they do:**
- `OLLAMA_BASE_URL`: Tells PAL where to find Ollama
- `DEFAULT_MODEL=auto`: PAL chooses best model for each task

---

## Verification & Testing

### Step 1: Verify Conda Environment

```powershell
# List conda environments
conda env list

# Should show:
# pal-mcp                  C:\Users\Egusto\anaconda3\envs\pal-mcp

# Activate and test
conda activate pal-mcp
python -c "import anthropic, openai; print('✓ All dependencies installed')"
```

### Step 2: Verify Ollama

```powershell
# Check Ollama is running
curl http://localhost:11434/api/tags

# Should return JSON with installed models

# List models
ollama list
```

### Step 3: Test Each CLI

**Claude Desktop:**
1. Open Claude Desktop
2. Look for MCP server indicator (bottom-right)
3. Ask: "Use pal to list available models"

**Codex CLI:**
```powershell
codex
/mcp
# Should show PAL with 18 tools
```

**Gemini CLI:**
```powershell
gemini mcp list
# Should show: pal: ... (stdio) - Disconnected (normal)

gemini "Use pal to list available models"
```

### Step 4: Test PAL Integration

Pick any CLI and try PAL tools:

```
> Use pal thinkdeep with deepseek-r1:32b-5090 to explain quantum computing

> Use pal consensus with fast and medium to evaluate: Should I use Rust or Go?

> Use pal codereview to review src/main.py
```

---

## Troubleshooting

### PAL MCP Server Not Connecting

**Symptom:** CLI shows "Disconnected" or "Error connecting to MCP server"

**Solutions:**

1. **Verify conda environment exists:**
   ```powershell
   conda env list | Select-String "pal-mcp"
   ```

2. **Test manual server start:**
   ```powershell
   conda activate pal-mcp
   cd C:\Users\Egusto\code\pal-mcp-server
   python server.py
   # Should start without errors
   ```

3. **Check paths in config:**
   - Verify `conda.bat` path exists
   - Verify `server.py` path exists
   - Use full paths (no `~` or environment variables)

4. **Check conda.bat location:**
   ```powershell
   # Should be at:
   C:\Users\Egusto\anaconda3\condabin\conda.bat

   # If using Miniconda:
   C:\Users\Egusto\miniconda3\condabin\conda.bat
   ```

### Ollama Models Not Appearing

**Symptom:** PAL can't find Ollama models

**Solutions:**

1. **Verify Ollama is running:**
   ```powershell
   ollama serve
   # Leave this running in a separate terminal
   ```

2. **Check Ollama API:**
   ```powershell
   curl http://localhost:11434/api/tags
   ```

3. **Verify environment variable:**
   ```
   OLLAMA_BASE_URL=http://localhost:11434
   ```
   (Must be in all three configs)

### Codex CLI Warnings

**Warning: `wire_api` deprecation**

**Solution:** Use `wire_api = "responses"` (not `"chat"`)

**Warning: `tools.web_search` deprecated**

**Solution:** Use `[features] web_search_request = true`

### Slow Startup (Codex/Gemini)

**Symptom:** "Loading personal and system profiles took 2732ms"

**Cause:** PowerShell profile loading (conda init, Oh My Posh, etc.)

**Solutions:**

1. **Skip profile:**
   ```powershell
   powershell -NoProfile -Command "codex"
   ```

2. **Create fast alias:**
   ```powershell
   # Add to $PROFILE:
   function cx { codex.exe $args }
   function gm { gemini.exe $args }
   ```

### Terminal Display Issues (Codex)

**Symptom:** Character-by-character output, word wrapping broken

**Solutions:**

1. **Use Windows Terminal** (best fix):
   ```powershell
   winget install Microsoft.WindowsTerminal
   wt codex
   ```

2. **Widen PowerShell window:**
   - Right-click title bar → Properties
   - Layout → Window Size → Width: 120+

3. **Force terminal size:**
   ```powershell
   $env:COLUMNS = 120
   codex
   ```

---

## Issues Fixed During Setup

### Issue 1: `wire_api` Deprecation Warning (Codex)

**Problem:**
```
⚠ Support for the "chat" wire API is deprecated
```

**Solution:**
```toml
[model_providers.ollama]
wire_api = "responses"  # Not "chat"
```

### Issue 2: Invalid `history.persistence` (Codex)

**Problem:**
```
Error: unknown variant `local`, expected `save-all` or `none`
```

**Solution:**
```toml
[history]
persistence = "save-all"  # Not "local"
```

### Issue 3: Invalid `tui.notifications` Syntax (Codex)

**Problem:**
```
Error: data did not match any variant of untagged enum Notifications
```

**Solution:**
Remove the entire `[tui]` section - defaults work fine.

### Issue 4: Web Search Deprecated (Codex)

**Problem:**
```
⚠ `tools.web_search` is deprecated
```

**Solution:**
```toml
[features]
web_search_request = true  # Not [tools] web_search
```

### Issue 5: Hardcoded Paths in PAL (Gemini's Changes)

**Problem:**
Gemini CLI modified `run-server.ps1` to use hardcoded conda path instead of flexible detection.

**Solution:**
```powershell
cd C:\Users\Egusto\code\pal-mcp-server
git restore run-server.ps1
```

This restored the original logic that checks for venv first before falling back to conda.

---

## Comparison: All Four CLIs

| Feature | Claude Desktop | Codex CLI | Gemini CLI | Copilot CLI |
|---------|---------------|-----------|------------|-------------|
| **Interface** | Desktop app | Terminal | Terminal | Terminal |
| **Config format** | JSON | TOML | JSON | JSON |
| **Config location** | `%APPDATA%\Claude\` | `~/.codex/` | `~/.gemini/` | `~/.copilot/` |
| **Model switching** | Manual (UI) | Profiles (`-p`) | `-m` flag | `--model` flag |
| **Local models** | ❌ Cloud only | ✅ Via Ollama | ❌ Cloud only | ❌ Cloud only |
| **PAL MCP** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Multi-model** | Via PAL | Via PAL | Via PAL | Via PAL |
| **Tool approval** | Automatic | Config-based | Config-based | Per-run flags |
| **Built-in MCP** | None | None | None | GitHub MCP |
| **Best for** | General chat | Local-first coding | Gemini features | GitHub integration |
| **API cost** | Claude API | Free (Ollama) | Gemini API | GitHub Copilot sub |

**Key Insight:** All four CLIs can use **local Ollama models via PAL MCP** for multi-model orchestration, even though three of them are cloud-based for their primary models.

---

## Advanced Configuration

### Adding More Model Profiles (Codex)

```toml
[profiles.uncensored]
model_provider = "ollama"
model = "dolphin3:8b-5090"

[profiles.vision]
model_provider = "ollama"
model = "NeuralNexusLab/CodeXor:12b"
```

### Restricting PAL to Specific Models

Add to all four configs:

```
OLLAMA_ALLOWED_MODELS=qwen2.5-coder:32b-5090,deepseek-r1:32b-5090
```

### Disabling Unused PAL Tools

Add to all four configs:

```
DISABLED_TOOLS=analyze,refactor,testgen,secaudit,docgen,tracer
```

### Mixing Local + Cloud Models (Codex)

```toml
[model_providers.openai]
name = "OpenAI"
base_url = "https://api.openai.com/v1"
env_key = "OPENAI_API_KEY"

[profiles.gpt4]
model_provider = "openai"
model = "gpt-4"
```

Then set `OPENAI_API_KEY` in PAL env.

---

## Summary

You now have **four AI CLIs** configured to use:

1. ✅ **Shared conda environment** (`pal-mcp`)
2. ✅ **Single PAL MCP Server instance**
3. ✅ **Local Ollama models** (100% free, private)
4. ✅ **18 PAL orchestration tools**

**Configuration files:**
- `%APPDATA%\Claude\claude_desktop_config.json`
- `~/.codex/config.toml`
- `~/.gemini/settings.json`
- `~/.copilot/mcp-config.json`

**All using the same command:**
```
C:\Users\Egusto\anaconda3\condabin\conda.bat run -n pal-mcp --no-capture-output python C:\Users\Egusto\code\pal-mcp-server\server.py
```

**Next steps:**
1. Explore PAL tools in each CLI
2. Try multi-model consensus workflows
3. Experiment with different model profiles
4. Automate tasks with Codex/Gemini CLI in scripts

---

## Files in This Repository

| File | Purpose |
|------|---------|
| `codex-config-conda.toml` | Codex CLI config (conda method) |
| `codex-config-venv.toml` | Codex CLI config (venv method) |
| `gemini-settings.json` | Gemini CLI config (conda method) |
| `copilot-mcp-config-conda.json` | Copilot CLI config (conda method) |
| `copilot-mcp-config-venv.json` | Copilot CLI config (venv method) |
| `docs/CLAUDE-CODEX-GEMINI-SETUP.md` | This comprehensive guide |
| `website/docs/tools/codex-cli.md` | Detailed Codex/Gemini/Copilot documentation |
| `docs/PAL-OLLAMA-INTEGRATION.md` | PAL + Ollama integration guide |

---

**Created:** January 3, 2026
**Author:** Christoph Acham
**Setup:** Windows 11, Anaconda, Ollama on RTX 5090 (32GB VRAM)
