---
sidebar_position: 1
---

# Architecture Overview

Understanding how the components fit together.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           WINDOWS HOST                              │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                        YOUR APPLICATIONS                      │  │
│  │                                                               │  │
│  │   ollama-manager.exe    PowerShell Scripts    IDE/Editor     │  │
│  │         │                      │                   │          │  │
│  └─────────┼──────────────────────┼───────────────────┼──────────┘  │
│            │                      │                   │             │
│            ▼                      ▼                   ▼             │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                     OLLAMA SERVER                             │  │
│  │                                                               │  │
│  │   REST API (:11434)  ◄──── OpenAI-Compatible Endpoints       │  │
│  │         │                                                     │  │
│  │         ▼                                                     │  │
│  │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │  │
│  │   │  qwen3:32b  │    │ deepseek-r1 │    │ llama3.3:70b│      │  │
│  │   │  [LOADED]   │    │             │    │             │      │  │
│  │   └──────┬──────┘    └─────────────┘    └─────────────┘      │  │
│  │          │                                                    │  │
│  └──────────┼────────────────────────────────────────────────────┘  │
│             │                                                       │
│             ▼                                                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      NVIDIA GPU (CUDA)                        │  │
│  │                                                               │  │
│  │   VRAM: Model weights loaded here for fast inference          │  │
│  │   Compute: Matrix operations for token generation             │  │
│  │                                                               │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                    WSL2 / CONTAINER RUNTIME                         │
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │   Open WebUI    │  │   Perplexica    │  │    SearXNG      │     │
│  │   :3000         │  │   :3002         │  │    :4000        │     │
│  │                 │  │                 │  │                 │     │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  Meta-search    │     │
│  │  │ Web UI    │  │  │  │ AI Search │  │  │  aggregator     │     │
│  │  │ Models    │  │  │  │ Citations │  │  │                 │     │
│  │  │ Search    │  │  │  │ Focus modes│ │  │  DDG, Google,   │     │
│  │  └───────────┘  │  │  └───────────┘  │  │  Bing, etc.     │     │
│  │        │        │  │        │        │  │                 │     │
│  └────────┼────────┘  └────────┼────────┘  └─────────────────┘     │
│           │                    │                                    │
│           └────────────────────┴───────────────────────────────────┤
│                                │                                    │
│                    Gateway IP (172.17.x.1)                         │
│                                │                                    │
└────────────────────────────────┼────────────────────────────────────┘
                                 │
                                 ▼
                    http://172.17.x.1:11434/api/...
                    (Ollama API on Windows host)
```

## Component Roles

### Ollama Server

The core inference engine:
- **Model Management** - Pull, list, remove models
- **Inference** - Load models into GPU, generate tokens
- **API Server** - OpenAI-compatible REST API
- **Memory Management** - LRU model caching

### Container Runtime (Docker/Podman)

Runs web interfaces in isolation:
- **Networking** - Bridge between containers and host
- **Storage** - Persistent volumes for data
- **Isolation** - Containers don't affect host system

### Web UIs (Open WebUI / Perplexica)

User-facing interfaces:
- **Chat Interface** - Conversations with models
- **Web Search** - Internet search integration
- **Model Selection** - Choose which model to use
- **Settings** - Configure behavior

### SearXNG

Meta-search engine for Perplexica:
- **Aggregation** - Queries multiple search engines
- **Privacy** - No tracking, no ads
- **Self-hosted** - Complete control

## Data Flow

### Chat Request

```
1. User types message in Open WebUI
2. WebUI sends POST to Ollama API
3. Ollama loads model (if not loaded)
4. GPU processes prompt, generates tokens
5. Tokens stream back to WebUI
6. WebUI displays response
```

### Web Search Request

```
1. User asks question in Perplexica
2. Perplexica sends query to SearXNG
3. SearXNG queries DDG, Google, etc.
4. Results returned to Perplexica
5. Perplexica sends results + question to Ollama
6. Ollama synthesizes answer with citations
7. Response displayed with sources
```

## Storage Layout

### Ollama Models

```
~/.ollama/
├── models/
│   ├── manifests/           # Model metadata (JSON)
│   │   └── registry.ollama.ai/
│   │       └── library/
│   │           └── qwen3/
│   │               └── 32b  # Manifest file
│   └── blobs/               # Model weights (binary)
│       ├── sha256-abc...    # Layer 1
│       └── sha256-def...    # Layer 2
└── history                  # Chat history
```

### Container Volumes

```
Docker/Podman volumes:
├── open-webui/              # WebUI data
│   ├── config/              # User settings
│   └── uploads/             # Uploaded files
└── perplexica/              # Perplexica data
    └── data/                # Search history
```

## Network Architecture

### Host Networking

```
Windows Host:
├── 127.0.0.1:11434  → Ollama API
├── 127.0.0.1:3000   → Open WebUI (forwarded from container)
├── 127.0.0.1:3002   → Perplexica (forwarded)
└── 127.0.0.1:4000   → SearXNG (forwarded)
```

### Container Networking

See [Network Architecture](/docs/architecture/network) for details on Podman/Docker networking.

## Security Model

### Host Access

- Ollama listens on 0.0.0.0:11434 (accessible from containers)
- No authentication by default
- API keys optional via `OLLAMA_API_KEY`

### Container Isolation

- Containers run as non-root users
- Limited file system access via volumes
- Network isolated except for exposed ports

### Data Privacy

- All inference runs locally
- No data sent to cloud (unless using cloud search providers)
- Models stored on local disk only

## Scaling Considerations

### Single User (Default)

```
1 Ollama instance
1-2 models loaded
1 WebUI container
```

### Multi-User

```
1 Ollama instance
OLLAMA_NUM_PARALLEL=4
Multiple WebUI sessions sharing Ollama
```

### High Availability

Not covered by this setup. For production:
- Load balancer in front of multiple Ollama instances
- Shared storage for models
- Container orchestration (Kubernetes)
