# PAL MCP Server + Ollama Integration

This guide explains how to configure PAL MCP Server to use your local Ollama models for multi-model orchestration with Claude Code.

## Why PAL + Ollama?

Open WebUI provides a chat interface with web search, but it's **single-model-per-chat** - you manually pick which model to use. There's no automatic routing.

PAL MCP Server enables **true multi-model orchestration** where Claude Code can:
- Use fast models (qwen2.5:3b) for quick queries
- Use powerful models (qwen2.5-coder:14b) for synthesis
- Run consensus workflows across multiple models
- Automatically route tasks to the best model

```
┌────────────────────────────────────────────────────────────────┐
│                     Claude Code Orchestration                   │
│                                                                 │
│  User: "What's new in React 19?"                               │
│                                                                 │
│  1. Claude Code → WebSearch → SearXNG (localhost:4000)         │
│  2. Claude Code → PAL thinkdeep with fast (qwen2.5:3b)         │
│  3. Claude Code → PAL thinkdeep with synthesis (coder:14b)     │
│  4. Claude Code synthesizes final response                      │
└────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Ollama running on `localhost:11434`
- PAL MCP Server cloned to `C:\Users\Egusto\code\pal-mcp-server`
- Claude Code with PAL MCP configured

## Configuration

### Step 1: Update PAL `.env`

Add Ollama as a custom provider in `pal-mcp-server/.env`:

```bash
# Local Ollama via OpenAI-compatible API
CUSTOM_API_URL=http://localhost:11434/v1
# No CUSTOM_API_KEY needed - Ollama doesn't require authentication
```

### Step 2: Update PAL `conf/custom_models.json`

Replace with the model definitions from this repo. Key models:

| Model | Alias | VRAM | Purpose |
|-------|-------|------|---------|
| qwen2.5:3b | `fast`, `search` | ~4GB | Quick queries, web search |
| qwen2.5-coder:14b | `synthesis`, `medium` | ~17GB | Code generation, synthesis |
| deepseek-r1:32b | `reasoning`, `r1` | ~24GB | Chain-of-thought reasoning |
| qwen2.5-coder:32b | `coder` | ~22GB | Best local coding |

### Step 3: Restart Claude Code

After configuration changes, restart Claude Code to pick up the new PAL settings.

### Step 4: Verify

Run `listmodels` in Claude Code to see your Ollama models with their aliases.

## Usage Examples

### Quick Query with Fast Model
```
thinkdeep with fast: summarize these search results
```

### Deep Analysis with Synthesis Model
```
thinkdeep with synthesis: analyze this code architecture
```

### Multi-Model Consensus
```
consensus with fast and synthesis: evaluate this API design
```

### Reasoning with DeepSeek
```
thinkdeep with reasoning: debug this complex issue step by step
```

## Web Search Workflow

With PAL + Ollama configured, Claude Code orchestrates the full workflow:

1. **Claude Code** receives your query
2. **WebSearch** (Claude's native tool) queries SearXNG at `localhost:4000`
3. **PAL thinkdeep** with `fast` (qwen2.5:3b) quickly summarizes results
4. **PAL thinkdeep** with `synthesis` (qwen2.5-coder:14b) provides deep analysis
5. **Claude Code** synthesizes the final response

This is **true agentic behavior** - not just RAG injection like Open WebUI.

## Model Selection Guide

| Task | Recommended | Alias |
|------|-------------|-------|
| Fast web queries | qwen2.5:3b | `fast` |
| Code generation | qwen2.5-coder:14b | `synthesis` |
| Complex reasoning | deepseek-r1:32b | `reasoning` |
| Best coding | qwen2.5-coder:32b | `coder` |
| Uncensored chat | dolphin3:8b | `uncensored` |

## VRAM Optimization

For RTX 5090 (32GB VRAM), the web search stack fits simultaneously:

| Model | VRAM |
|-------|------|
| qwen2.5:3b | ~4GB |
| qwen2.5-coder:14b | ~17GB |
| **Total** | **~21GB** |

This leaves ~11GB for context windows.

## Troubleshooting

### Models not appearing in listmodels
- Verify `CUSTOM_API_URL=http://localhost:11434/v1` is set in PAL `.env`
- Ensure Ollama is running: `ollama serve`
- Check PAL logs for connection errors

### Slow responses
- Larger models need time to load into VRAM
- First query to a model is slower (cold start)
- Use `fast` alias for quick queries

### Connection refused
- Ollama must be running before PAL starts
- Check firewall isn't blocking localhost:11434

## Files Reference

| File | Purpose |
|------|---------|
| `pal-mcp-server/.env` | PAL configuration with `CUSTOM_API_URL` |
| `pal-mcp-server/conf/custom_models.json` | Model definitions and aliases |
| `ollama-rtx-setup/custom_models.json` | Reference model configs for this repo |

## Architecture Comparison

| Feature | Open WebUI | PAL + Claude Code |
|---------|------------|-------------------|
| Model selection | Manual dropdown | Automatic routing |
| Multi-model | No | Yes (consensus, debate) |
| Web search | SearXNG injection | Native + orchestrated |
| Orchestrator | None | Claude Code |
| True agentic | No | Yes |

## Related Documentation

- [Web Search Integration](./guides/web-search.md)
- [Model Selection Guide](./guides/model-selection.md)
- [PAL MCP Server Docs](https://github.com/BeehiveInnovations/pal-mcp-server)
