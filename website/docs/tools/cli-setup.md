---
sidebar_label: CLI Setup Guide
sidebar_position: 1
title: AI CLI Integration with PAL MCP
description: Setup guide for Codex CLI, Gemini CLI, Copilot CLI, and Claude Desktop with PAL MCP Server
---

# AI CLI Integration with PAL MCP

Complete guide to setting up **Codex CLI**, **Gemini CLI**, **GitHub Copilot CLI**, and **Claude Desktop** with PAL MCP Server for multi-model orchestration with your local Ollama models.

## Supported CLIs

| CLI | Config Location | Format |
|-----|----------------|--------|
| **Claude Desktop** | `%APPDATA%\Claude\claude_desktop_config.json` | JSON |
| **Codex CLI** | `~/.codex/config.toml` | TOML |
| **Gemini CLI** | `~/.gemini/settings.json` | JSON |
| **Copilot CLI** | `~/.copilot/mcp-config.json` | JSON |

## Why PAL MCP?

Combined with PAL MCP Server, you get:

- ✅ **Multi-model orchestration** - Route tasks to best model automatically
- ✅ **Local-first** - All models run on your RTX 5090 via Ollama
- ✅ **Consensus workflows** - Compare responses across multiple models
- ✅ **Advanced tools** - Code review, debugging, security audits, etc.
- ✅ **Web search** - Integrated with your SearXNG instance

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Codex CLI Workflow                       │
│                                                              │
│  User: "Review this code for security issues"               │
│                                                              │
│  1. Codex CLI → PAL MCP Server (via conda env)              │
│  2. PAL → Ollama (localhost:11434)                          │
│  3. PAL orchestrates: qwen2.5-coder:32b-5090                │
│  4. Optional: Consensus with deepseek-r1:32b-5090           │
│  5. Codex synthesizes final response                         │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Ollama** running on `localhost:11434` with models installed
2. **PAL MCP Server** installed and configured
3. **Conda environment** (if using conda setup) or Python venv
4. **Codex CLI** installed (`npm install -g @openai/codex-cli`)

## Installation

### Step 1: Install Codex CLI

```powershell
# Using npm
npm install -g @openai/codex-cli

# Verify installation
codex --version
# Output: codex-cli 0.77.0
```

### Step 2: Choose Your PAL MCP Setup Method

We support two methods: **Conda** (recommended if you use conda) or **Virtual Environment** (standard Python).

---

## Method A: Conda Setup (Recommended)

### Why Conda?

- ✅ Environment isolation (no conflicts with system Python)
- ✅ Easier dependency management (`conda update`)
- ✅ Same environment can be shared with Claude Desktop
- ✅ Better for Windows users (no PATH issues)

### 1. Create Conda Environment

```powershell
# Create environment
conda create -n pal-mcp python=3.11 -y

# Activate and install dependencies
conda activate pal-mcp
pip install anthropic openai google-generativeai requests mcp
```

### 2. Add to Claude Desktop (Optional)

If you also use Claude Desktop, add to `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "pal": {
      "command": "C:\\Users\\YOUR_USERNAME\\anaconda3\\condabin\\conda.bat",
      "args": [
        "run",
        "-n",
        "pal-mcp",
        "--no-capture-output",
        "python",
        "C:\\Users\\YOUR_USERNAME\\code\\pal-mcp-server\\server.py"
      ]
    }
  }
}
```

### 3. Create Codex Configuration

Save as `C:\Users\YOUR_USERNAME\.codex\config.toml`:

```toml
# Codex CLI Configuration for Windows + Conda
# Location: C:\Users\YOUR_USERNAME\.codex\config.toml

# ============================================
# Model Providers Configuration
# ============================================

[model_providers.ollama]
name = "Ollama"
base_url = "http://localhost:11434/v1"
wire_api = "responses"  # Fixes deprecation warning

# ============================================
# Model Profiles
# ============================================
# Quick reference:
#   -p qwen-code    → qwen2.5-coder:32b-5090 (19GB, best local coding)
#   -p deepseek     → deepseek-r1:32b-5090   (19GB, reasoning with CoT)
#   -p fast         → qwen2.5:3b             (2GB, quick queries)
#   -p medium       → qwen2.5-coder:14b      (9GB, balanced)

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
command = "C:\\Users\\YOUR_USERNAME\\anaconda3\\condabin\\conda.bat"
args = [
    "run",
    "-n",
    "pal-mcp",
    "--no-capture-output",
    "python",
    "C:\\Users\\YOUR_USERNAME\\code\\pal-mcp-server\\server.py"
]

# Timeouts - from official PAL guide
startup_timeout_sec = 300   # 5 minutes for conda env activation
tool_timeout_sec = 1200      # 20 minutes for tool execution

[mcp_servers.pal.env]
OLLAMA_BASE_URL = "http://localhost:11434"
DEFAULT_MODEL = "auto"  # Let PAL auto-select best model

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

**Important:** Replace `YOUR_USERNAME` with your actual Windows username!

### 4. Test the Setup

```powershell
# Start Codex
codex

# Inside Codex, test MCP connection
/mcp

# Should show:
# • pal
#   • Status: enabled
#   • Tools: analyze, chat, codereview, consensus, debug, etc.

# Test PAL integration
> Use pal to list available models

# Test a simple query
> Write a hello world in Python
```

---

## Method B: Virtual Environment Setup

### Why Virtual Environment?

- ✅ Standard Python approach (no conda needed)
- ✅ Lighter weight
- ✅ Faster startup (no conda activation overhead)

### 1. Create Virtual Environment

```powershell
# Clone PAL MCP Server
cd C:\Users\YOUR_USERNAME\code
git clone https://github.com/BeehiveInnovations/pal-mcp-server
cd pal-mcp-server

# Create virtual environment
python -m venv .pal_venv

# Activate and install dependencies
.\.pal_venv\Scripts\Activate.ps1
pip install anthropic openai google-generativeai requests mcp
```

### 2. Create Codex Configuration

Save as `C:\Users\YOUR_USERNAME\.codex\config.toml`:

```toml
# Codex CLI Configuration (Virtual Environment)

[model_providers.ollama]
name = "Ollama"
base_url = "http://localhost:11434/v1"
wire_api = "responses"

# ... (same profiles as conda version) ...

# ============================================
# MCP Servers Configuration - Using venv
# ============================================

[[mcp_servers]]
name = "pal"
transport = "stdio"
command = "C:\\Users\\YOUR_USERNAME\\code\\pal-mcp-server\\.pal_venv\\Scripts\\python.exe"
args = ["C:\\Users\\YOUR_USERNAME\\code\\pal-mcp-server\\server.py"]
tool_timeout_sec = 1200

[mcp_servers.pal.env]
OLLAMA_BASE_URL = "http://localhost:11434"
DEFAULT_MODEL = "auto"

[features]
web_search_request = true

[defaults]
provider = "ollama"
model = "qwen2.5-coder:32b-5090"
```

**Key Differences from Conda:**
- Uses `[[mcp_servers]]` syntax (array) instead of `[mcp_servers.pal]` (table)
- Includes `transport = "stdio"` explicitly
- Points directly to Python executable in venv
- No conda.bat wrapper
- No startup_timeout_sec (venv starts instantly)

---

## Configuration Explained

### Model Providers

```toml
[model_providers.ollama]
base_url = "http://localhost:11434/v1"  # Ollama's OpenAI-compatible API
wire_api = "responses"                   # New API format (fixes deprecation warning)
```

### Model Profiles

Profiles let you switch models with `-p` flag:

```powershell
codex -p fast       # Uses qwen2.5:3b (2GB VRAM)
codex -p deepseek   # Uses deepseek-r1:32b-5090 (19GB VRAM)
codex -p qwen-code  # Uses qwen2.5-coder:32b-5090 (19GB VRAM)
```

Add profiles for all your installed models:

```toml
[profiles.custom-model]
model_provider = "ollama"
model = "your-model:tag"
```

### MCP Server Timeouts

```toml
startup_timeout_sec = 300   # Conda env activation can take time
tool_timeout_sec = 1200     # PAL operations can be long (consensus, etc.)
```

**Why these values?**
- Conda activation: ~10-30s (we allow 5 minutes for safety)
- PAL tools (consensus, codereview): 5-20 minutes depending on complexity

### Features

```toml
[features]
web_search_request = true  # Required for PAL's apilookup tool
```

**What this enables:**
- PAL can fetch latest API documentation
- Web search integration with SearXNG (if configured)
- Real-time information lookup

---

## Usage Examples

### Basic Chat

```powershell
# Interactive mode
codex
> Write a function to parse JSON

# One-off query
codex chat "explain async/await in Python"
```

### Using PAL Tools

```powershell
codex
> Use pal codereview to review src/auth.py

> Use pal thinkdeep with deepseek-r1:32b-5090 to debug this memory leak

> Use pal consensus with fast and medium to evaluate this API design
```

### Model Switching

```powershell
# Quick queries with fast model
codex -p fast
> What's new in Python 3.13?

# Deep analysis with reasoning model
codex -p deepseek
> Analyze the time complexity of this algorithm

# Default coding model
codex
> Refactor this class to use dependency injection
```

---

## Comparison: Conda vs Virtual Environment

| Feature | Conda | Virtual Environment |
|---------|-------|---------------------|
| Startup speed | ~10-30s | ~1-2s |
| Environment isolation | Excellent | Good |
| Dependency management | `conda update` | `pip install -U` |
| Windows compatibility | Excellent | Good |
| Disk space | ~500MB | ~200MB |
| Shared with Claude Desktop | ✅ Yes | ❌ No |
| Complexity | Medium | Low |
| **Recommended for** | Windows users, conda users | Linux/macOS, Python developers |

---

## Common Issues We Fixed

During setup, we encountered and fixed several issues:

### Issue 1: `wire_api` Deprecation Warning

**Problem:**
```
⚠ Support for the "chat" wire API is deprecated
```

**Solution:**
Set `wire_api = "responses"` in model provider:
```toml
[model_providers.ollama]
wire_api = "responses"  # Not "chat"
```

### Issue 2: Invalid `history.persistence` Value

**Problem:**
```
Error: unknown variant `local`, expected `save-all` or `none`
```

**Solution:**
```toml
[history]
persistence = "save-all"  # Not "local"
```

### Issue 3: Invalid `tui.notifications` Syntax

**Problem:**
```
Error: data did not match any variant of untagged enum Notifications
```

**Solution:**
Remove the broken notifications config entirely. The default works fine:
```toml
# DON'T use this (broken):
# [tui]
# notifications = { types = ["agent-turn-complete"] }

# Just omit it - defaults work fine
```

### Issue 4: Terminal Display Garbled (Character-by-Character Output)

**Problem:**
Each token appears on separate line with "Worked for Xs" between them:
```
• name
─ Worked for 13s ──────
• ":
─ Worked for 13s ──────
• "
```

**Root Cause:** Terminal width detection failing in MinGW/Git Bash/default PowerShell

**Solutions (Try in Order):**

**A. Use Windows Terminal (BEST FIX)**
```powershell
# Install Windows Terminal
winget install Microsoft.WindowsTerminal

# Run Codex in it
wt codex
```

**B. Increase PowerShell Window Width**
1. Right-click PowerShell title bar → Properties
2. Layout tab → Window Size → Width: 120 (or more)
3. Restart PowerShell and try `codex` again

**C. Run in WSL (if you have it)**
```bash
# In WSL
codex
# Terminal detection works better in WSL
```

**D. Use Chat Mode Instead of TUI**
```powershell
# Skip the broken TUI entirely
codex chat "your question here"
```

**E. Force Environment Variable**
```powershell
$env:COLUMNS = 120
$env:LINES = 40
codex
```

### Issue 5: Web Search Deprecated Warning

**Problem:**
```
⚠ `tools.web_search` is deprecated. Use `[features].web_search_request`
```

**Solution:**
```toml
# OLD (deprecated)
[tools]
web_search = true

# NEW (correct)
[features]
web_search_request = true
```

### Issue 6: Slow PowerShell Startup (2732ms Profile Load)

**Problem:**
```
Loading personal and system profiles took 2732ms.
```

**Root Cause:** Your PowerShell profile (`$PROFILE`) has slow initialization (conda, Oh My Posh, etc.)

**Solutions:**

**Option A: Skip Profile When Running Codex**
```powershell
powershell -NoProfile -Command "codex"
```

**Option B: Create a Fast Alias**
Add to your `$PROFILE`:
```powershell
# Fast alias that doesn't reload profile
function cx { codex.exe $args }
```

**Option C: Optimize Your PowerShell Profile**
```powershell
# Find what's slow
Measure-Command { . $PROFILE }

# Comment out slow sections (conda init, Oh My Posh, etc.)
```

---

## Troubleshooting

### PAL MCP not connecting

```powershell
# Check if conda env exists
conda env list | Select-String "pal-mcp"

# Test manual activation
conda activate pal-mcp
python C:\Users\YOUR_USERNAME\code\pal-mcp-server\server.py
```

### Models not appearing

```powershell
# Verify Ollama is running
ollama list

# Check PAL can reach Ollama
curl http://localhost:11434/api/tags
```

### Wire API deprecation warning

Make sure you have `wire_api = "responses"` in your config:

```toml
[model_providers.ollama]
wire_api = "responses"  # Not "chat"
```

### Slow PowerShell startup (2732ms)

This is your PowerShell profile loading, not Codex. To skip:

```powershell
powershell -NoProfile -Command "codex"
```

Or create an alias in your profile:
```powershell
function cx { codex.exe $args }
```

---

## Advanced Configuration

### Add More Ollama Models

```toml
[profiles.uncensored]
model_provider = "ollama"
model = "dolphin3:8b-5090"

[profiles.vision]
model_provider = "ollama"
model = "NeuralNexusLab/CodeXor:12b"  # Supports vision
```

### Mix Local + Cloud Models

```toml
# Add OpenAI provider
[model_providers.openai]
name = "OpenAI"
base_url = "https://api.openai.com/v1"
env_key = "OPENAI_API_KEY"

[profiles.gpt4]
model_provider = "openai"
model = "gpt-4"
```

Then in PAL env:
```toml
[mcp_servers.pal.env]
OLLAMA_BASE_URL = "http://localhost:11434"
OPENAI_API_KEY = "sk-..."  # For cloud models
```

### Restrict PAL to Specific Models

```toml
[mcp_servers.pal.env]
OLLAMA_ALLOWED_MODELS = "qwen2.5-coder:32b-5090,deepseek-r1:32b-5090"
```

### Disable PAL Tools You Don't Use

```toml
[mcp_servers.pal.env]
DISABLED_TOOLS = "analyze,refactor,testgen,secaudit,docgen,tracer"
```

---

## Integration with This Repo's Setup

If you followed the main setup in this repo, you already have:

1. ✅ Ollama installed with `-5090` optimized models
2. ✅ SearXNG running on `localhost:4000`
3. ✅ Open WebUI with web search configured

**Codex CLI complements Open WebUI:**

| Feature | Open WebUI | Codex CLI |
|---------|------------|-----------|
| Interface | Browser | Terminal |
| Multi-model | Manual dropdown | Automatic routing via PAL |
| Web search | SearXNG injection | Native + PAL orchestration |
| Workflows | Single model | Multi-model consensus |
| Use case | Chat, experimentation | Coding, automation, CI/CD |

**Recommended workflow:**
- Use **Open WebUI** for interactive chat and experimentation
- Use **Codex CLI** for coding tasks, code review, automation

---

## Files Reference

| File | Purpose |
|------|---------|
| `~/.codex/config.toml` | Codex CLI configuration |
| `pal-mcp-server/.env` | PAL environment variables (optional) |
| `custom_models.json` | Model definitions for PAL (from this repo) |
| `~/.codex/history.jsonl` | Session history |

---

## Next Steps

1. **Try PAL tools:** `/mcp` in Codex to see all available tools
2. **Set up aliases:** See `setup-codex-aliases.ps1` in this repo
3. **Integrate with CI/CD:** Use `codex chat` in GitHub Actions
4. **Explore consensus workflows:** Compare multiple models on same task

---

---

## Gemini CLI Setup (Bonus)

Google's Gemini CLI also supports MCP! The setup is nearly identical to Codex.

### Installation

```powershell
# Install Gemini CLI
npm install -g @google/generative-ai-cli

# Verify installation
gemini --version
```

### Configuration

Gemini uses `~/.gemini/settings.json` instead of a TOML file:

**Copy the template:**
```powershell
cp gemini-settings.json ~/.gemini/settings.json
```

**Edit and replace `YOUR_USERNAME`** with your actual Windows username.

**Gemini settings.json structure:**
```json
{
  "mcpServers": {
    "pal": {
      "command": "C:\\Users\\YOUR_USERNAME\\anaconda3\\condabin\\conda.bat",
      "args": [
        "run",
        "-n",
        "pal-mcp",
        "--no-capture-output",
        "python",
        "C:\\Users\\YOUR_USERNAME\\code\\pal-mcp-server\\server.py"
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

### Usage

```powershell
# Launch Gemini CLI
gemini

# Check MCP servers
gemini mcp list

# Use PAL tools (similar to Codex)
gemini "Use pal to list available models"
```

### Key Differences: Codex vs Gemini

| Feature | Codex CLI | Gemini CLI |
|---------|-----------|------------|
| Config format | TOML | JSON |
| Config location | `~/.codex/config.toml` | `~/.gemini/settings.json` |
| Model profiles | Built-in (via config) | Set with `-m` flag |
| Provider | OpenAI (Ollama via OSS mode) | Google Gemini (cloud) |
| MCP support | ✅ Yes | ✅ Yes |
| Local models | ✅ Via Ollama | ❌ Cloud only (but PAL uses Ollama) |
| Web search | Native feature flag | Not built-in (use PAL) |
| Best for | Local-first, coding | Gemini-specific features |

**Recommendation:** Use **Codex CLI** for local-first workflows with Ollama. Use **Gemini CLI** if you want Google's latest models alongside your local Ollama models via PAL.

---

## GitHub Copilot CLI Setup

GitHub Copilot CLI (`gh copilot`) can also use PAL MCP Server for multi-model orchestration.

### Installation

```powershell
# Install GitHub Copilot CLI extension
gh extension install github/copilot-cli

# Verify installation
gh copilot --version
# Output: @github/copilot-cli version 0.0.374
```

### Configuration

Create `~/.copilot/mcp-config.json`:

**Conda Setup (recommended):**
```json
{
  "mcpServers": {
    "pal": {
      "type": "local",
      "command": "C:\\Users\\YOUR_USERNAME\\anaconda3\\condabin\\conda.bat",
      "tools": ["*"],
      "args": [
        "run",
        "-n",
        "pal-mcp",
        "--no-capture-output",
        "python",
        "C:\\Users\\YOUR_USERNAME\\code\\pal-mcp-server\\server.py"
      ],
      "env": {
        "OLLAMA_BASE_URL": "http://localhost:11434",
        "DEFAULT_MODEL": "auto"
      }
    }
  }
}
```

**Python venv Setup:**
```json
{
  "mcpServers": {
    "pal": {
      "type": "local",
      "command": "C:\\Users\\YOUR_USERNAME\\code\\pal-mcp-server\\.pal_venv\\Scripts\\python.exe",
      "tools": ["*"],
      "args": [
        "C:\\Users\\YOUR_USERNAME\\code\\pal-mcp-server\\server.py"
      ],
      "env": {
        "OLLAMA_BASE_URL": "http://localhost:11434",
        "DEFAULT_MODEL": "auto"
      }
    }
  }
}
```

:::warning Critical Requirement
The `"tools": ["*"]` field is **REQUIRED** for Copilot CLI. Without it, you'll get:
```
Failed to start MCP Servers
```
This is different from Claude Desktop and Gemini which don't require this field.
:::

### Usage

```powershell
# Launch Copilot CLI
gh copilot

# Allow PAL tools
gh copilot --allow-tool pal:*

# Use PAL for multi-model consensus
gh copilot "Use pal to get a consensus on the best approach"
```

### CLI Comparison Matrix

| Feature | Claude Desktop | Codex CLI | Gemini CLI | Copilot CLI |
|---------|---------------|-----------|------------|-------------|
| Config format | JSON | TOML | JSON | JSON |
| Config location | `%APPDATA%\Claude\*` | `~/.codex/*` | `~/.gemini/*` | `~/.copilot/*` |
| Requires `tools` array | No | No | No | **Yes** |
| Best for | Chat UI | Local coding | Gemini models | GitHub integration |
| MCP support | ✅ | ✅ | ✅ | ✅ |

---

## Related Documentation

- [PAL MCP Server](https://github.com/BeehiveInnovations/pal-mcp-server)
- [Codex CLI Documentation](https://openai.github.io/codex-cli/)
- [Gemini CLI Documentation](https://github.com/google/generative-ai-cli)
- [GitHub Copilot CLI](https://docs.github.com/en/copilot/github-copilot-in-the-cli)
- [Model Selection Guide](../guides/model-selection.md)
- [Comprehensive CLI Setup Guide (all 4 CLIs)](/docs/CLAUDE-CODEX-GEMINI-SETUP.md)
