---
sidebar_position: 2
---

# Web Search Integration

Enable AI-powered web search with your local Ollama models.

## Which Setup Should I Use?

**Both setups use SearXNG** for multi-engine search - you always get the full experience:

| Setup | Interface | Best For |
|-------|-----------|----------|
| **Open WebUI** | ChatGPT-like chat | General chat with web search capability |
| **Perplexica** | Perplexity-like research | AI research with inline citations |

### What is SearXNG?

SearXNG is a **meta-search engine** - it queries multiple search engines at once and combines their results:

```
┌─────────────┐
│   SearXNG   │──→ DuckDuckGo ──→ results
│  (combines  │──→ Google ──────→ results  ──→ Aggregated
│   results)  │──→ Bing ────────→ results      Results
│             │──→ Brave ───────→ results
│             │──→ Wikipedia ───→ results
└─────────────┘
```

### Quick Decision Guide

| Want This? | Install This | Containers |
|------------|--------------|------------|
| Chat + multi-engine web search | Open WebUI | 2 (Open WebUI + SearXNG) |
| AI research with citations (Perplexity-like) | Perplexica | 3 (Perplexica + SearXNG) |
| Everything | Both | 4 (share SearXNG) |

:::note
Open WebUI now always includes SearXNG for multi-engine search. There's no "basic search" option - you get the full experience by default.
:::

:::tip Key Insight
If you install Perplexica, you get SearXNG automatically. Open WebUI can then use that same SearXNG instance for multi-engine search too!
:::

## Why Web Search?

LLMs have a knowledge cutoff date. Web search integration allows your local AI to:
- Answer questions about current events
- Look up documentation and APIs
- Research topics in real-time
- Cite sources for factual claims

## Feature Comparison

| Feature | Open WebUI | Perplexica |
|---------|------------|------------|
| **Interface** | ChatGPT-like | Perplexity-like |
| **Search engines** | Multi-engine via SearXNG | Multi-engine via SearXNG |
| **Privacy** | 100% self-hosted | 100% self-hosted |
| **Setup complexity** | 2 containers | 3 containers |
| **Best for** | General chat | Privacy-focused research |
| **Citations** | Basic source links | Numbered references throughout |

## Option 1: Open WebUI

A beautiful, feature-rich chat interface with built-in web search.

### Installation

**Recommended (single-user mode - no login required):**
```powershell
.\setup-ollama-websearch.ps1 -Setup OpenWebUI -SingleUser
```

**Standard (with user accounts):**
```powershell
.\setup-ollama-websearch.ps1 -Setup OpenWebUI
```

### Access

Open http://localhost:3000

### What Gets Pre-Configured

The setup script automatically configures:
- **Web search** - Pre-enabled with DuckDuckGo (or SearXNG if available)
- **Models** - All your installed Ollama models pre-selected
- **Session persistence** - Secret key saved so you stay logged in across restarts

### First-Time Setup

With `-SingleUser`: **Nothing to do!** Open the URL and start chatting.

Without `-SingleUser`:
1. Create an account (first user becomes admin)
2. Web search is **pre-configured** automatically

### Web Search Configuration

Open WebUI always uses SearXNG for web search, which is automatically started alongside it:

| Component | Port | Description |
|-----------|------|-------------|
| Open WebUI | 3000 | Chat interface |
| SearXNG | 4000 | Multi-engine search aggregator |

This gives you:
- **No rate limits** - Self-hosted search
- **Multi-engine** - Queries DuckDuckGo, Google, Bing, Brave, etc. simultaneously
- **Complete privacy** - All searches stay on your network

To customize search engines, edit `searxng/settings.yml` after installation.

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
3. Under **Chat Model**, select **Ollama** and choose a model:
   - `qwen2.5:3b` for fast queries
   - `qwen2.5:14b` for better synthesis
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

## International Search Engines

### Yandex Cloud API Setup

The built-in Yandex engine in SearXNG is blocked by CAPTCHAs. Use Yandex Cloud's official Search API instead for reliable Russian-language search.

#### Step 1: Create Yandex Cloud Account

1. Go to [console.yandex.cloud](https://console.yandex.cloud)
2. Sign up or log in with your Yandex account
3. Create a billing account (free tier available)

#### Step 2: Create Service Account

1. In the Yandex Cloud console, go to your folder
2. Navigate to **IAM** → **Service accounts**
3. Click **Create service account**
4. Name it `searxng-search`
5. Click **Create**

#### Step 3: Assign Search API Role

1. Click on your new service account
2. Go to **Roles** tab
3. Click **Assign role**
4. Add role: `search-api.webSearch.user`

#### Step 4: Generate API Key

1. In your service account, go to **API keys** tab
2. Click **Create API key**
3. Select scope: `yc.search-api.execute`
4. **Save the key immediately** - shown only once!

#### Step 5: Configure Environment

Create a `.env` file in the project root (never commit this!):

```bash
# Copy from .env.example
cp .env.example .env

# Edit with your credentials
YANDEX_API_KEY=your-api-key-here
YANDEX_FOLDER_ID=your-folder-id-here
```

Your folder ID is in the console URL: `console.yandex.cloud/folders/YOUR_FOLDER_ID`

#### Step 6: Restart SearXNG

```powershell
# Restart to pick up new environment variables
podman-compose -f docker-compose-perplexica.yml down
podman-compose -f docker-compose-perplexica.yml up -d
```

#### Usage

Yandex Cloud Search is now available alongside other engines. Your queries will automatically include Russian search results.

:::tip Free Tier
Yandex Cloud offers 10,000 free search queries per day - more than enough for personal use.
:::

### Baidu Search (Chinese)

For Chinese-language search, Baidu integration requires CAPTCHA handling. See the [advanced search configuration](#advanced-multi-language-search) section.

### Advanced: Multi-Language Search

For comprehensive international search with translation:

1. **Query in English** → Results from all engines
2. **SearXNG aggregates** → DuckDuckGo + Google + Yandex + Baidu
3. **LLM synthesizes** → Translates and combines results

The LLM (GPT-4, Claude, Qwen) naturally handles translation when presenting results to you in English.

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

The setup script installs optimized models for web search (RTX 5090, 32GB VRAM):

| Task | Recommended Model | VRAM |
|------|-------------------|------|
| Quick lookups | qwen2.5:3b | ~4GB |
| Synthesis & code | qwen2.5-coder:14b | ~17GB |

**Total: ~21GB** - both models fit in VRAM simultaneously, leaving ~11GB for context.

For deep research or academic work, you can manually load larger models like `qwen3:32b` or `deepseek-r1:32b` (Ollama will swap as needed).

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

## Testing Your Setup

By default, the setup script just starts containers quickly. Use `-Test` to verify everything works:

```powershell
.\setup-ollama-websearch.ps1 -Test
```

### What Gets Tested

| Test | What It Checks |
|------|----------------|
| Container health | All containers running and healthy |
| Model inference | Each model responds to a simple prompt |
| Web endpoints | Open WebUI, SearXNG, Perplexica respond |

### Troubleshooting

If something isn't working, use `-Diagnose`:

```powershell
.\setup-ollama-websearch.ps1 -Diagnose
```

Shows: container runtime, Ollama status, container status, network config, and logs for unhealthy containers.

### Manual Testing

Test SearXNG engines individually:

```powershell
.\test-searxng-engines.ps1
```

Sample output:
```
[OK]   duckduckgo    (3 results, 0.8s)
[OK]   google        (5 results, 1.2s)
[WARN] bing          (0 results - may be rate-limited)
[OK]   wikipedia     (2 results, 0.5s)

Summary: 3/4 engines working
```

### Test API Directly

```powershell
# Test model inference
$body = @{model="qwen2.5:3b"; prompt="Say OK"; stream=$false} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -Body $body -ContentType "application/json"

# Test SearXNG
Invoke-RestMethod -Uri "http://localhost:4000/search?q=test&format=json"
```
