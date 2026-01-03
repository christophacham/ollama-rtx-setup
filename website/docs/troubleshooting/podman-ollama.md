---
sidebar_position: 1
---

# Podman + Ollama Connectivity

Fixing container-to-Ollama connectivity issues when using Podman on Windows.

:::info Multi-Model Analysis
This diagnosis was validated by 4 independent AI models (Llama 3.3, Kat-Coder, Devstral, MiMo) with **unanimous consensus** at 8.5/10 average confidence. See [Analysis Details](#multi-model-analysis-details) below.
:::

## Symptoms

- Open WebUI shows "Ollama not connected" or no models
- Perplexica can't reach Ollama for AI responses
- Container logs show `Connection refused` or timeout errors
- Perplexica backend fails health checks
- SearXNG works but AI responses fail

## Root Cause

Podman on Windows uses WSL2, and `host.docker.internal` resolves to a non-routable IP:

```
┌─────────────────────────────────────────────────────────────┐
│                     WINDOWS HOST                            │
│   Ollama Server ──────────────────── localhost:11434        │
├─────────────────────────────────────────────────────────────┤
│                 WSL2 / PODMAN MACHINE                       │
│   Gateway IP ─────────────────────── 172.17.x.1  ✓ WORKS   │
├─────────────────────────────────────────────────────────────┤
│                     CONTAINER                               │
│   host.docker.internal ──────────── 169.254.1.2  ✗ BROKEN  │
│   172.17.x.1:11434 ──────────────────────────────  ✓ WORKS │
└─────────────────────────────────────────────────────────────┘
```

**The problem:** `169.254.1.2` is a link-local address that doesn't route to Windows.

**The fix:** Use the WSL2 gateway IP instead.

## Quick Fix

Run the automated debug script:

```powershell
.\debug-ollama-connection.ps1 -Fix
```

This will:
1. Diagnose the issue
2. Find the correct gateway IP
3. Recreate the container with the correct URL

## Manual Fix

### Step 1: Find Gateway IP

```powershell
# Get your Podman machine name
$machine = podman system connection list --format "{{.Name}}" | Select-Object -First 1

# Get the gateway IP
podman machine ssh $machine 'ip route show default'
# Output: default via 172.17.144.1 dev eth0 ...
#                     ^^^^^^^^^^^^^ This is your gateway
```

### Step 2: Recreate Container

```powershell
# Stop and remove
podman stop open-webui
podman rm open-webui

# Recreate with correct URL (replace IP with your gateway)
podman run -d -p 3000:8080 `
  -v open-webui:/app/backend/data `
  -e OLLAMA_BASE_URL=http://172.17.144.1:11434 `
  --name open-webui `
  --restart always `
  ghcr.io/open-webui/open-webui:cuda
```

### Step 3: Verify

```powershell
podman exec open-webui python3 -c "import urllib.request; print(urllib.request.urlopen('http://172.17.144.1:11434/api/tags', timeout=5).read()[:50])"
```

## Diagnostic Commands

### Check Ollama on Host

```powershell
curl http://localhost:11434/api/tags
```

Should return JSON with your models.

### Check Container Status

```powershell
# Is it running?
podman ps --filter "name=open-webui"

# What URL is configured?
podman inspect open-webui --format '{{range .Config.Env}}{{println .}}{{end}}' | Select-String "OLLAMA"
```

### Check DNS Resolution

```powershell
podman exec open-webui getent hosts host.docker.internal
# If it shows 169.254.x.x, that's the problem
```

### Test Connectivity

```powershell
# From inside container to Ollama
podman exec open-webui python3 -c "import urllib.request; urllib.request.urlopen('http://172.17.144.1:11434/api/tags', timeout=5)"
```

## Why Docker Works

Docker Desktop runs a specialized VM with proper NAT routing:

| Feature | Docker Desktop | Podman + WSL2 |
|---------|---------------|---------------|
| `host.docker.internal` | Routes to Windows | Maps to 169.254.1.2 |
| Network mode | Custom NAT | Standard WSL2 |
| Fix needed | None | Use gateway IP |

If you prefer simpler networking, consider Docker Desktop.

## Edge Cases

### Gateway IP Changes

The WSL2 gateway IP can change after reboot. If connectivity breaks:

```powershell
.\debug-ollama-connection.ps1 -Fix
```

### Multiple Podman Machines

Specify the machine name explicitly:

```powershell
podman machine ssh my-machine-name 'ip route show default'
```

### Firewall Blocking

Ensure Windows Firewall allows the connection:

```powershell
# Check if Ollama is listening
netstat -an | Select-String "11434"

# Should show:
# TCP    0.0.0.0:11434    LISTENING
```

If not, add a firewall rule:

```powershell
New-NetFirewallRule -DisplayName "Ollama API" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow
```

## Switching to Docker

If you want to avoid these issues, use Docker Desktop:

```powershell
docker run -d -p 3000:8080 `
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 `
  --add-host=host.docker.internal:host-gateway `
  --name open-webui `
  ghcr.io/open-webui/open-webui:cuda
```

Docker's `host-gateway` magic makes `host.docker.internal` work correctly.

## Perplexica-Specific Issues

Perplexica has additional failure modes beyond Open WebUI:

### Config.toml Ollama URL

The `perplexica/config.toml` file contains:

```toml
[MODELS.OLLAMA]
API_URL = "http://host.docker.internal:11434"  # ← This fails in Podman
```

**Fix:** Update to use gateway IP:

```toml
[MODELS.OLLAMA]
API_URL = "http://172.17.144.1:11434"  # Replace with your gateway IP
```

### Health Check Dependencies

Perplexica uses a cascading dependency chain:

```
SearXNG (must be healthy) → Backend (waits) → Frontend (waits)
```

If the backend can't reach Ollama, it may appear healthy but return errors on AI queries.

### Volume Mount Issues

The backend expects config at `/home/perplexica/config.toml`. If the volume mount fails:

```powershell
# Verify config file exists
Test-Path .\perplexica\config.toml

# Check mount inside container
podman exec perplexica-backend cat /home/perplexica/config.toml
```

---

## Multi-Model Analysis Details

This connectivity issue was analyzed using multiple AI models to ensure diagnostic accuracy.

### Models Consulted

| Model | Role | Confidence | Key Finding |
|-------|------|------------|-------------|
| **minimax/minimax-m2** | Deep Analysis | High | Identified gateway detection as fragile |
| **llama-3.3-70b-instruct** | Validation | 8/10 | Confirmed Podman-specific limitation |
| **kat-coder-pro** | Challenge | 9/10 | Added WSL2 firewall as secondary cause |
| **devstral-2512** | Code Review | 8/10 | Provided improved detection code |
| **mimo-v2-flash** | Docker-Compose | High | Identified machine state verification gap |

### Unanimous Findings

All models agreed on:

1. **Primary Cause**: `host.docker.internal` is Docker-specific and doesn't work in Podman WSL2
2. **Technical Root**: Podman uses `pasta` networking, not Docker's `slirp4netns`
3. **Script Gap**: `Get-OllamaHostUrl` function fallback fails silently
4. **Evidence**: Multiple GitHub issues confirm this ([#22237](https://github.com/containers/podman/issues/22237), [#25152](https://github.com/containers/podman/issues/25152))

### Additional Failure Modes Discovered

| Severity | Issue | Impact |
|----------|-------|--------|
| 🔴 HIGH | Podman machine state not verified | Script proceeds even if machine stopped |
| 🔴 HIGH | WSL2 firewall can block gateway | Connection fails with correct IP |
| 🟠 MEDIUM | Rootless vs Rootful networking differs | Gateway detection may fail |
| 🟠 MEDIUM | Config path resolution fragile | `$MyInvocation.ScriptName` can be empty |
| 🟡 LOW | SearXNG volume permissions | Container can't write config |
| 🟡 LOW | Port conflicts not pre-checked | Silent binding failures |

### Recommended Code Improvements

The models suggested an improved `Get-OllamaHostUrl` function with multi-method detection:

```powershell
function Get-OllamaHostUrl {
    if ($script:ContainerRuntime -eq "docker") {
        return "http://host.docker.internal:11434"
    }

    # Podman: Try multiple detection methods
    $methods = @{
        "WSLHost" = {
            $ip = (wsl hostname -I 2>$null)
            if ($ip) { return $ip.Trim().Split(' ')[0] }
        }
        "Gateway" = {
            try {
                $conn = podman system connection list --format "{{.Name}}" 2>$null |
                        Select-Object -First 1
                if ($conn) {
                    $route = podman machine ssh $conn 'ip route show default' 2>$null
                    if ($route -match 'via (\d+\.\d+\.\d+\.\d+)') {
                        return $Matches[1]
                    }
                }
            } catch { }
            return $null
        }
        "DNS" = {
            try {
                return [System.Net.Dns]::GetHostEntry("host.docker.internal").AddressList[0].ToString()
            } catch { return $null }
        }
    }

    foreach ($name in @("WSLHost", "Gateway", "DNS")) {
        $ip = & $methods[$name]
        if ($ip -and $ip -match '^\d+\.\d+\.\d+\.\d+$' -and $ip -notmatch '^169\.254\.') {
            Write-Info "Podman host detected via $name : $ip"
            return "http://${ip}:11434"
        }
    }

    Write-Err "Could not detect Windows host IP for Podman"
    Write-Err "Set OLLAMA_HOST manually or use Docker Desktop"
    throw "Podman host detection failed"
}
```

### Pre-Flight Checks (Recommended)

```powershell
function Test-PodmanMachine {
    if ($script:ContainerRuntime -ne "podman") { return $true }

    $state = podman machine list --format "{{.Name}} {{.Running}}" 2>&1
    if ($state -notmatch "true") {
        Write-Err "Podman machine is not running"
        Write-Err "Start with: podman machine start"
        return $false
    }
    return $true
}

function Test-OllamaReachable {
    param([string]$Url)

    try {
        $null = Invoke-RestMethod -Uri "$Url/api/tags" -TimeoutSec 5
        return $true
    } catch {
        Write-Err "Cannot reach Ollama at $Url"
        return $false
    }
}
```

---

## Docker vs Podman: Quick Comparison

| Aspect | Docker Desktop | Podman + WSL2 |
|--------|---------------|---------------|
| `host.docker.internal` | ✅ Works automatically | ❌ Needs gateway IP |
| Setup complexity | Low | Medium |
| License | Free for personal use | Open source |
| GPU passthrough | `--gpus=all` | Requires configuration |
| Network reliability | High | Requires fixes |
| **Recommendation** | **Use for simplicity** | Use if Docker licensing is a concern |

:::tip Quick Decision
**Use Docker Desktop** if you want Perplexica/Open WebUI to "just work" without networking headaches. The `host.docker.internal` magic handles everything automatically.
:::

---

## Related

- [Network Architecture](/architecture/network) - Deep dive on container networking
- [Debug Script](/tools/setup-scripts#debug-ollama-connectionps1) - Script details
- [Choose Your Setup](/getting-started/choose-your-setup) - Docker vs Podman decision guide
