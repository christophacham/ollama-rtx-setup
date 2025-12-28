---
sidebar_position: 2
---

# Choose Your Setup

Not sure which components to install? This guide helps you decide.

## The Quick Answer

```
┌─────────────────────────────────────────────────────────────┐
│                 What do you want to do?                     │
└─────────────────────────────────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
   Just run models    Chat interface    AI Research
   (API/terminal)     with web search   (Perplexity-like)
         │                 │                 │
         ▼                 ▼                 ▼
   ┌─────────────┐  ┌─────────────┐  ┌──────────────┐
   │   Ollama    │  │ Open WebUI  │  │  Perplexica  │
   │    only     │  │             │  │  + SearXNG   │
   └─────────────┘  └─────────────┘  └──────────────┘

   setup-ollama.ps1  setup-ollama-     setup-ollama-
                     websearch.ps1     websearch.ps1
                     -Setup OpenWebUI  -Setup Perplexica
```

## Detailed Comparison

| I want to... | Install | Containers | Command |
|--------------|---------|------------|---------|
| Use AI from terminal/scripts | Ollama only | 0 | `setup-ollama.ps1` |
| **Chat UI (ready to use)** | Open WebUI | 1 | `setup-ollama-websearch.ps1 -Setup OpenWebUI -SingleUser` |
| Chat with a nice UI | Open WebUI | 1 | `setup-ollama-websearch.ps1 -Setup OpenWebUI` |
| Chat + search the web | Open WebUI | 1 | Same as above |
| Search multiple engines at once | Open WebUI + SearXNG | 2 | Install Perplexica first, then Open WebUI |
| Get AI research with citations | Perplexica + SearXNG | 3 | `setup-ollama-websearch.ps1 -Setup Perplexica` |
| Have everything | Both | 3 | `setup-ollama-websearch.ps1 -Setup Both` |

:::tip Personal Use Recommendation
Add `-SingleUser` to skip account creation. Open WebUI will be immediately usable with:
- No login required
- Web search pre-enabled
- All your models pre-selected
:::

## Understanding the Components

### Ollama
**What it is**: The AI engine that runs models on your GPU.

**You need this if**: You want to run AI locally. Period. Everything else builds on Ollama.

```
Terminal ──→ Ollama ──→ GPU ──→ Response
```

### Open WebUI
**What it is**: A ChatGPT-like web interface for Ollama.

**You need this if**: You want a nice UI instead of the terminal.

```
Browser ──→ Open WebUI ──→ Ollama ──→ Response
```

**Setup options**:
- `-SingleUser` - No login, ready to use immediately (recommended for personal use)
- Standard - First user to sign up becomes admin

**Pre-configured features**:
- Web search enabled with DuckDuckGo (or SearXNG if available)
- All installed models pre-selected
- Persistent sessions (stay logged in across restarts)

**Web search**: Open WebUI can search the web, but only **one search engine at a time** (DuckDuckGo OR Google OR Brave - you pick one in settings).

### SearXNG
**What it is**: A meta-search engine that queries multiple search engines at once.

**You need this if**: You want comprehensive search results from many sources.

```
Query ──→ SearXNG ──→ DuckDuckGo ──→┐
                 ──→ Google ───────→├──→ Combined Results
                 ──→ Bing ─────────→┤
                 ──→ Wikipedia ────→┘
```

**Key point**: SearXNG runs as a separate container. If you install Perplexica, you get SearXNG automatically.

### Perplexica
**What it is**: A Perplexity AI clone that provides research-style answers with citations.

**You need this if**: You want AI to research topics and cite its sources.

```
Question ──→ Perplexica ──→ SearXNG ──→ Web Results
                   │                        │
                   └───→ Ollama ←───────────┘
                            │
                            ▼
                 Answer with [1][2][3] citations
```

**Requires**: SearXNG (installed automatically with Perplexica).

## Common Questions

### Can I use both Open WebUI and Perplexica?

Yes! They share Ollama and can share SearXNG too.

```
setup-ollama-websearch.ps1 -Setup Both
```

This gives you:
- Open WebUI at http://localhost:3000
- Perplexica at http://localhost:3002
- SearXNG at http://localhost:4000

### Can Open WebUI use multiple search engines?

Only if you also install SearXNG. By default, Open WebUI uses one engine at a time.

**To get multi-engine search in Open WebUI:**
1. Install Perplexica (gets you SearXNG)
2. In Open WebUI settings, change search provider to SearXNG

### Which should I start with?

**Start with Open WebUI.** It's simpler and covers 90% of use cases. You can always add Perplexica later.

### Do I need Docker or Podman?

Only for the web interfaces (Open WebUI, Perplexica, SearXNG). Ollama runs natively on Windows.

## Visual Summary

```
┌────────────────────────────────────────────────────────────────────┐
│                        WHAT YOU CAN INSTALL                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  REQUIRED                                                          │
│  ────────                                                          │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                         OLLAMA                                │ │
│  │              (runs models on your GPU)                        │ │
│  │                      :11434                                   │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                               ▲                                    │
│                               │                                    │
│  OPTIONAL WEB UIs             │                                    │
│  ───────────────              │                                    │
│  ┌──────────────────┐    ┌────┴───────────────┐                   │
│  │    Open WebUI    │    │     Perplexica     │                   │
│  │      :3000       │    │       :3002        │                   │
│  │                  │    │                    │                   │
│  │  ChatGPT-like    │    │  Perplexity-like   │                   │
│  │  1 search engine │    │  Research + cites  │                   │
│  └────────┬─────────┘    └─────────┬──────────┘                   │
│           │                        │                               │
│           │         OPTIONAL       │  REQUIRED                     │
│           │         ───────        │  ────────                     │
│           │              ┌─────────▼─────────┐                     │
│           └─────────────►│     SearXNG       │                     │
│             (can use     │      :4000        │                     │
│              if running) │                   │                     │
│                          │  Multi-engine     │                     │
│                          │  meta-search      │                     │
│                          └───────────────────┘                     │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

## Next Steps

- [Quick Start](/getting-started/quick-start) - Get running in 5 minutes
- [Web Search Guide](/guides/web-search) - Detailed web search setup
- [Architecture Overview](/architecture/overview) - How it all fits together
