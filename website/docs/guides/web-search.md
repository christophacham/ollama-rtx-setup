---
sidebar_position: 2
---

# Web Search Integration

Enable AI-powered web search with your local Ollama models.

## Why Web Search?

LLMs have a knowledge cutoff date. Web search integration allows your local AI to:
- Answer questions about current events
- Look up documentation and APIs
- Research topics in real-time
- Cite sources for factual claims

## Two Options

| Feature | Open WebUI | Perplexica |
|---------|------------|------------|
| **Interface** | ChatGPT-like | Perplexity-like |
| **Search providers** | 15+ (DuckDuckGo, Google, Brave) | SearXNG (meta-search) |
| **Privacy** | Depends on provider | 100% self-hosted |
| **Setup complexity** | Single container | 3 containers |
| **Best for** | General use | Privacy-focused research |

## Option 1: Open WebUI

A beautiful, feature-rich chat interface with built-in web search.

### Installation

```powershell
.\setup-ollama-websearch.ps1 -Setup OpenWebUI
```

### Access

Open http://localhost:3000

### First-Time Setup

1. Create an account (first user becomes admin)
2. Go to **Settings → Admin Settings → Web Search**
3. Enable web search
4. Choose a provider:
   - **DuckDuckGo** - No API key needed (recommended to start)
   - **Google** - Requires API key
   - **Brave** - Requires API key (privacy-focused)
   - **SearXNG** - Self-hosted meta-search

### Usage

In any chat, prefix your query with the web search command:

```
/web What's the latest version of Node.js?
```

Or enable "Auto Web Search" for automatic detection.

### Why Open WebUI?

- **Familiar interface** - If you've used ChatGPT, you'll feel at home
- **Rich features** - File uploads, image generation, code execution
- **Active development** - Frequent updates, large community
- **Easy setup** - One container, minimal configuration

## Option 2: Perplexica + SearXNG

A Perplexity AI alternative that's 100% self-hosted and private.

### Installation

```powershell
.\setup-ollama-websearch.ps1 -Setup Perplexica
```

### Access

- Perplexica: http://localhost:3002
- SearXNG: http://localhost:4000

### Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Perplexica     │────▶│    SearXNG      │────▶│  Search Engines │
│  Frontend       │     │  (Meta-Search)  │     │  (DDG, Google)  │
│  :3002          │     │  :4000          │     │                 │
└────────┬────────┘     └─────────────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐
│  Perplexica     │────▶ Ollama (:11434)
│  Backend        │
│  :3001          │
└─────────────────┘
```

### Why Perplexica?

- **Complete privacy** - No data leaves your network
- **Source citations** - Every answer includes references
- **Focus modes** - Academic, writing, Wolfram Alpha, YouTube, Reddit
- **Meta-search** - SearXNG aggregates multiple search engines

### Configuration

The setup script auto-generates `perplexica/config.toml` with the correct Ollama URL:
- **Docker**: Uses `host.docker.internal:11434`
- **Podman**: Auto-detects gateway IP (e.g., `172.x.x.1:11434`)

To manually configure, edit `perplexica/config.toml`:

```toml
[GENERAL]
PORT = 3001
SIMILARITY_MEASURE = "cosine"

[API_ENDPOINTS]
SEARXNG = "http://searxng:8080"
OLLAMA = "http://172.17.144.1:11434"  # Podman gateway IP (auto-detected)
```

:::tip Container Config Path
Inside the container, the config is at `/home/perplexica/config.toml` (not `/app/`).
:::

### SearXNG Customization

Edit `searxng/settings.yml` to enable/disable search engines:

```yaml
engines:
  - name: duckduckgo
    disabled: false
  - name: google
    disabled: false  # Requires no API key
  - name: wikipedia
    disabled: false
  - name: github
    disabled: false
  - name: stackoverflow
    disabled: false
```

## Comparing Search Results

### Open WebUI Search

```
User: What's new in Python 3.13?

AI: Based on my web search, Python 3.13 was released on October 7, 2024
with these key features:
- Free-threaded mode (experimental)
- JIT compiler (experimental)
- Improved error messages
- ...

[Sources: python.org, realpython.com]
```

### Perplexica Search

```
User: What's new in Python 3.13?

AI: # Python 3.13 Release Notes

Python 3.13 introduced several significant changes:

## Free-Threaded Mode
The GIL can now be disabled experimentally... [1]

## JIT Compiler
A new JIT compiler improves performance... [2]

Sources:
[1] docs.python.org/3/whatsnew/3.13.html
[2] realpython.com/python313-new-features/
```

## Best Practices

### Model Selection for Search

Use fast models for search synthesis:

| Task | Recommended Model |
|------|-------------------|
| Quick lookups | llama3.1:8b |
| Deep research | qwen3:32b |
| Academic work | deepseek-r1:32b |

### Prompt Engineering

For better search results:

```
Instead of: "Tell me about React"
Try: "What are the new features in React 19 released in 2024?"
```

Specific questions get better search results.

### Rate Limiting

Some search providers have rate limits. For heavy usage:
- Use SearXNG (self-hosted, no limits)
- Rotate between providers
- Cache frequent queries

## Troubleshooting

### "No search results"

1. Check search provider is configured
2. Verify internet connectivity from container
3. Try a different search provider

### "Container can't reach Ollama"

This is a common Podman/WSL2 issue. See [Podman Networking](/troubleshooting/podman-ollama).

### "SearXNG returns empty results"

Some engines may be blocked or rate-limited:

```powershell
# Access SearXNG directly to test
curl http://localhost:4000/search?q=test&format=json
```
