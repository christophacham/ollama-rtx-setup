# PAL MCP Setup with Conda - Quick Guide

## Your Setup
- ✅ Conda environment: `pal-mcp`
- ✅ Server location: `C:\Users\Egusto\code\pal-mcp-server\`
- ✅ Already configured for Claude Desktop

## Setup for Codex CLI

### 1. Save the config.toml
Download `config-conda.toml` and save it to:
```
C:\Users\Egusto\.codex\config.toml
```

### 2. Verify Conda Environment
Make sure your pal-mcp conda environment is ready:

```powershell
# Activate the environment
conda activate pal-mcp

# Verify dependencies are installed
pip list | findstr anthropic

# If missing, install:
pip install anthropic openai google-generativeai
```

### 3. Test PAL MCP
```powershell
# Start a new Codex session
codex --oss -m qwen2.5-coder:32b-5090

# Inside Codex, test PAL:
> Use pal to list available models
```

## How Your Setup Works

**For Claude Desktop:**
```bash
claude mcp add --transport stdio pal -- \
  C:\Users\Egusto\anaconda3\condabin\conda.bat run \
  -n pal-mcp --no-capture-output python \
  C:\Users\Egusto\code\pal-mcp-server\server.py
```

**For Codex CLI (in config.toml):**
```toml
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
```

Both use the same conda environment and server!

## Usage Examples

Once configured, use PAL from Codex:

```powershell
# Start Codex
cx

# Inside Codex session:
> Use pal to get deepseek-r1's opinion on this architecture

> Use consensus with qwen2.5-coder:32b and deepseek-r1:32b on the best approach

> clink with codex codereviewer to audit auth.py in a fresh context

> Use pal to analyze this code for performance issues
```

## Troubleshooting

**"pal not found" error:**
1. Check conda environment exists: `conda env list`
2. Verify server.py path exists: `dir C:\Users\Egusto\code\pal-mcp-server\server.py`

**Timeout errors:**
- Already configured with 20-minute timeout in the config
- For longer tasks, PAL will handle retries

**Model not available:**
- Run `Use pal to list available models` in Codex
- Check OLLAMA_ALLOWED_MODELS in config if you set restrictions

## Benefits of Your Conda Setup

✅ **Isolated environment** - PAL dependencies don't conflict with other projects
✅ **Easy updates** - Just `conda activate pal-mcp && git pull` in the server directory
✅ **Same setup** - Works for both Claude Desktop and Codex CLI
✅ **Reproducible** - Conda environment can be exported and shared
