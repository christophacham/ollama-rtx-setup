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
2. Web search is **pre-configured** automatically

### Web Search Auto-Detection

The setup script automatically detects the best search provider:

| Scenario | Search Engine | Notes |
|----------|---------------|-------|
| **Perplexica installed** | SearXNG | Self-hosted, no rate limits |
| **OpenWebUI only** | DuckDuckGo | No setup needed, may have rate limits |

To change providers later, go to **Settings → Admin Settings → Web Search**:
- **SearXNG** - Self-hosted (if Perplexica running)
- **DuckDuckGo** - No API key needed
- **Google** - Requires API key
- **Brave** - Requires API key (privacy-focused)

### Usage

1. Click the **+** button next to the message input
2. Toggle **Web Search** on
3. Type your query - results will include web sources

Or prefix your query with `/web`:

```
/web What's the latest version of Node.js?
```

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

### First-Time Setup

1. Open http://localhost:3002
2. Click the settings icon (gear) in the sidebar
3. Under **Chat Model**, select **Ollama** and choose a model (e.g., `llama3.1:8b`)
4. Under **Embedding Model**, select **Local** and choose `BGE Small`
5. Click **Save** and start searching

### Using Perplexica

Type your question and press Enter. Perplexica will:
1. Search the web via SearXNG
2. Read and analyze relevant sources
3. Synthesize an answer with citations

#### Focus Modes

Select a focus mode before searching for optimized results:

| Mode | Best For |
|------|----------|
| **All** | General web searches |
| **Academic** | Research papers and scholarly articles |
| **YouTube** | Finding video content |
| **Reddit** | Community discussions and opinions |
| **Wolfram Alpha** | Math, calculations, data queries |
| **Writing** | Writing help (no web search) |

#### Tips

- Be specific: "React 19 new features 2024" works better than "tell me about React"
- Use Academic mode for technical documentation
- Larger models (32B) give better synthesis but are slower

### Configuration

The setup script auto-generates `perplexica/config.toml` with the correct Ollama URL:
- **Docker**: Uses `host.docker.internal:11434`
- **Podman**: Auto-detects gateway IP (e.g., `172.x.x.1:11434`)

To manually configure, edit `perplexica/config.toml`:

```toml
[GENERAL]
PORT = 3001
SIMILARITY_MEASURE = "cosine"
KEEP_ALIVE = "5m"

[MODELS.OLLAMA]
API_URL = "http://172.17.144.1:11434"

[MODELS.OPENAI]
API_KEY = ""

[API_ENDPOINTS]
SEARXNG = "http://searxng:8080"
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
