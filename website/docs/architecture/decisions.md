---
sidebar_position: 3
---

# Architecture Decisions

Key decisions and their rationale (Architecture Decision Records).

## ADR-001: Local LLMs over Cloud APIs

**Status:** Accepted

**Context:**
Cloud LLM APIs (OpenAI, Anthropic, Google) are easy to use but have trade-offs.

**Decision:**
Focus on local inference with Ollama.

**Rationale:**

| Factor | Cloud API | Local Ollama |
|--------|-----------|--------------|
| **Privacy** | Data sent to third party | Data never leaves machine |
| **Cost** | Per-token pricing | One-time hardware cost |
| **Latency** | Network round-trip | Local, sub-second |
| **Availability** | Depends on provider | Always available |
| **Control** | Provider's terms | Complete control |

**Trade-offs:**
- Requires capable GPU (12GB+ VRAM)
- Initial setup complexity
- Models may lag behind cloud offerings

---

## ADR-002: Ollama as Inference Engine

**Status:** Accepted

**Context:**
Multiple options exist for local LLM inference: llama.cpp, vLLM, Ollama, LM Studio.

**Decision:**
Use Ollama as the primary inference engine.

**Rationale:**

| Aspect | Ollama | llama.cpp | vLLM |
|--------|--------|-----------|------|
| **Installation** | One command | Compile from source | Python setup |
| **Model management** | `ollama pull` | Manual GGUF | HuggingFace |
| **Windows support** | Native | WSL required | Limited |
| **API** | OpenAI-compatible | Custom | OpenAI-compatible |
| **GPU optimization** | Automatic | Manual flags | Manual tuning |

**Why not others?**
- **llama.cpp**: More control but requires compilation and manual management
- **vLLM**: Excellent for production but complex setup, limited Windows support
- **LM Studio**: GUI-focused, less scriptable

---

## ADR-003: Support Both Docker and Podman

**Status:** Accepted

**Context:**
Container runtime needed for web UIs. Docker Desktop is popular but proprietary. Podman is open-source but has quirks.

**Decision:**
Support both Docker and Podman with automatic detection.

**Rationale:**
- Docker Desktop: Easier setup, better `host.docker.internal` support
- Podman: Open source, no licensing concerns, lighter weight

**Implementation:**
```powershell
# Auto-detect in scripts
if (docker info) { use docker }
elseif (podman info) { use podman }
```

**Trade-offs:**
- Must maintain workarounds for Podman networking (gateway IP detection)
- Testing overhead for both runtimes

---

## ADR-004: Gateway IP for Podman Networking

**Status:** Accepted

**Context:**
Podman on WSL2 doesn't route `host.docker.internal` correctly to Windows. Containers can't reach Ollama.

**Decision:**
Detect and use the WSL2 gateway IP instead of `host.docker.internal`.

**Rationale:**
```
host.docker.internal → 169.254.1.2 (link-local, doesn't route)
Gateway IP → 172.17.x.1 (correctly routes to Windows)
```

**Implementation:**
```powershell
$gateway = podman machine ssh $machine 'ip route show default' |
           Select-String 'via (\d+\.\d+\.\d+\.\d+)' |
           % { $_.Matches.Groups[1].Value }
```

**Trade-offs:**
- Gateway IP can change on reboot
- Requires SSH into Podman machine to detect
- Added complexity vs Docker's "just works"

---

## ADR-005: No Embedded Ollama in Containers

**Status:** Accepted

**Context:**
Open WebUI offers an `:ollama` tag with Ollama bundled inside the container.

**Decision:**
Use `:cuda` or `:main` tags (no embedded Ollama).

**Rationale:**
- **Single source of truth**: One Ollama instance, one model library
- **GPU access**: Host Ollama has native GPU access; container Ollama needs complex passthrough
- **Simplicity**: Models managed in one place
- **Updates**: Update Ollama independently of WebUI

**Trade-offs:**
- Requires network connectivity between container and host
- Additional troubleshooting for connectivity issues

---

## ADR-006: PowerShell for Scripts

**Status:** Accepted

**Context:**
Scripts need to run on Windows. Options: Batch, PowerShell, Python, Go.

**Decision:**
Use PowerShell for all automation scripts.

**Rationale:**
- **Native to Windows**: No additional runtime needed
- **Powerful**: Object pipeline, error handling, functions
- **Container support**: Works with Docker and Podman CLI
- **User familiarity**: Windows users know PowerShell basics

**Why not Python?**
- Would require Python installation
- Virtual environments add complexity
- PowerShell is already there

---

## ADR-007: Container Image Mirroring

**Status:** Accepted

**Context:**
Upstream container images can change unexpectedly. Registries can have outages.

**Decision:**
Mirror images to personal GHCR with digest tracking.

**Rationale:**
- **Reproducibility**: Pin exact image versions
- **Availability**: Not dependent on upstream uptime
- **Control**: Review updates before adopting

**Implementation:**
- GitHub Actions runs daily sync
- `container-versions.json` tracks digests
- `-UseLocalRegistry` flag for opt-in usage

**Trade-offs:**
- Storage costs on GHCR (free tier usually sufficient)
- Sync delay for urgent security updates

---

## ADR-008: Model Recommendations by VRAM

**Status:** Accepted

**Context:**
Users have different GPUs with different VRAM. Need sensible defaults.

**Decision:**
Recommend models based on available VRAM with smart quantization choices.

**Rationale:**

| VRAM | Max Model | Quality |
|------|-----------|---------|
| 12GB | 7-13B @ Q4-Q8 | Good for basic tasks |
| 24GB | 32B @ Q4-Q6 | Excellent quality |
| 32GB | 70B @ Q4, 32B @ Q8 | Best open models |

**Implementation:**
Script detects VRAM via nvidia-smi and selects appropriate models.

---

## ADR-009: Dark-First Documentation Theme

**Status:** Accepted

**Context:**
Documentation site needs a visual theme. Most developer tools use dark mode.

**Decision:**
Use dark mode as default theme (with light mode toggle available).

**Rationale:**
- Terminal/dev aesthetic matches the CLI-focused tooling
- Easier on eyes for extended reading
- Consistent with Ollama's own dark branding
- GitHub dark mode is popular among target audience

---

## ADR-010: Go + BubbleTea for TUI

**Status:** Accepted

**Context:**
Wanted a simple model manager TUI. Options: Go, Rust, Python (textual/rich).

**Decision:**
Use Go with BubbleTea framework.

**Rationale:**
- **Single binary**: No runtime dependencies
- **Cross-compilation**: Build Windows EXE from any OS
- **BubbleTea**: Mature, well-documented TUI framework
- **Size**: ~2.5MB binary, acceptable

**Why not Rust?**
- Steeper learning curve for simple TUI
- Go is sufficient for this use case

**Why not Python?**
- Would require Python runtime
- Packaging as EXE is complex (PyInstaller)
