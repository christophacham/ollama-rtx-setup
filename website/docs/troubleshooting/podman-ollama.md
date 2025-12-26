---
sidebar_position: 1
---

# Podman + Ollama Connectivity

Fixing container-to-Ollama connectivity issues when using Podman on Windows.

## Symptoms

- Open WebUI shows "Ollama not connected" or no models
- Perplexica can't reach Ollama for AI responses
- Container logs show `Connection refused` or timeout errors

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

## Related

- [Network Architecture](/architecture/network) - Deep dive on container networking
- [Debug Script](/tools/setup-scripts#debug-ollama-connectionps1) - Script details
