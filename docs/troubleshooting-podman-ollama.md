# Troubleshooting: Podman + Ollama Connectivity

This guide helps diagnose and fix connectivity issues between containers (Open WebUI, Perplexica) and Ollama when using Podman on Windows.

## Table of Contents
- [Problem Overview](#problem-overview)
- [Quick Fix](#quick-fix)
- [Network Architecture](#network-architecture)
- [Diagnostic Commands](#diagnostic-commands)
- [Manual Fix Steps](#manual-fix-steps)
- [Using the Debug Script](#using-the-debug-script)

---

## Problem Overview

### Symptoms
- Open WebUI shows "Ollama not connected" or no models
- Perplexica can't reach Ollama for AI responses
- Container logs show connection refused/timeout to Ollama

### Root Cause
Podman on Windows uses WSL2, creating this network topology:

```
┌─────────────────────────────────────────────────────────────┐
│                     WINDOWS HOST                            │
│                                                             │
│   Ollama Server ──────────────────── localhost:11434        │
│        │                                                    │
│        │ (listening on 0.0.0.0:11434)                       │
│        │                                                    │
├────────┼────────────────────────────────────────────────────┤
│        │              WSL2 / PODMAN MACHINE                 │
│        │                                                    │
│        ▼                                                    │
│   Gateway IP ─────────────────────── 172.17.x.1             │
│        │                                                    │
│        │ (this is the correct route to Windows)             │
│        │                                                    │
├────────┼────────────────────────────────────────────────────┤
│        │              CONTAINER NETWORK                     │
│        │                                                    │
│   Container ──────────────────────── 172.17.x.y             │
│        │                                                    │
│        ├── host.docker.internal ──── 169.254.1.2 (BROKEN!)  │
│        │                                                    │
│        └── Needs: http://172.17.x.1:11434 (WORKS!)          │
└─────────────────────────────────────────────────────────────┘
```

**The Problem:** Podman sets `host.docker.internal` to `169.254.1.2` (a link-local address), but this doesn't route to Windows. Docker Desktop handles this correctly; Podman on WSL2 does not.

---

## Quick Fix

**TL;DR for experienced users:**

```powershell
# 1. Find your Podman machine's gateway IP
podman machine ssh $(podman system connection list --format "{{.Name}}" | Select-Object -First 1) 'ip route show default'
# Output: default via 172.17.144.1 dev eth0 ...
#                     ^^^^^^^^^^^^^ This is your gateway

# 2. Recreate container with correct URL
podman stop open-webui && podman rm open-webui

podman run -d -p 3000:8080 \
  -v open-webui:/app/backend/data \
  -e OLLAMA_BASE_URL=http://172.17.144.1:11434 \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:cuda

# 3. Verify
podman exec open-webui python3 -c "import urllib.request; print(urllib.request.urlopen('http://172.17.144.1:11434/api/tags', timeout=5).read()[:50])"
```

Or just run the debug script:
```powershell
.\debug-ollama-connection.ps1 -Fix
```

---

## Network Architecture

### Why Docker Works But Podman Doesn't

| Feature | Docker Desktop | Podman + WSL2 |
|---------|---------------|---------------|
| `host.docker.internal` | Routed correctly to Windows | Maps to 169.254.1.2 (broken) |
| Network mode | Custom NAT with proper routing | Standard WSL2 networking |
| Fix required | None | Use gateway IP instead |

### Finding the Correct Gateway

The Podman machine (WSL2 VM) has a default gateway that routes to Windows:

```bash
# SSH into the Podman machine
podman machine ssh <machine-name> 'ip route show default'

# Output example:
# default via 172.17.144.1 dev eth0 proto kernel
#             ^^^^^^^^^^^^
#             This IP reaches Windows!
```

---

## Diagnostic Commands

Run these step-by-step to identify the issue:

### Step 1: Verify Ollama is Running on Host

**PowerShell:**
```powershell
Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 5
```

**Bash/CMD:**
```bash
curl http://localhost:11434/api/tags
```

**Expected:** JSON response with your models list.

**If this fails:** Ollama isn't running. Start it with `ollama serve`.

---

### Step 2: Check Container Status

```powershell
# Is the container running?
podman ps --filter "name=open-webui"

# What image is it using?
podman inspect open-webui --format "{{.Config.Image}}"

# What OLLAMA_BASE_URL is configured?
podman inspect open-webui --format '{{range .Config.Env}}{{println .}}{{end}}' | Select-String "OLLAMA"
```

**Expected:** Container running with `OLLAMA_BASE_URL=http://<some-ip>:11434`

---

### Step 3: Check Host Resolution Inside Container

```powershell
podman exec open-webui getent hosts host.docker.internal
```

**Expected output:**
```
169.254.1.2    host.docker.internal
```

**This is the problem!** 169.254.1.2 doesn't route to Windows.

---

### Step 4: Test Connectivity from Container

```powershell
# Test with the configured URL (likely fails)
podman exec open-webui python3 -c "import urllib.request; urllib.request.urlopen('http://host.docker.internal:11434/api/tags', timeout=5)"
```

**Expected error:**
```
urllib.error.URLError: <urlopen error [Errno 111] Connection refused>
```

This confirms the container can't reach Ollama via `host.docker.internal`.

---

### Step 5: Find the Correct Gateway IP

```powershell
# List Podman machines
podman system connection list

# Get the default machine name
$machine = (podman system connection list --format "{{.Name}}" | Select-Object -First 1)

# Get the gateway IP
podman machine ssh $machine 'ip route show default'
```

**Expected output:**
```
default via 172.17.144.1 dev eth0 proto kernel
```

The IP after `via` is your gateway (e.g., `172.17.144.1`).

---

### Step 6: Test Connectivity via Gateway

```powershell
# Replace with your gateway IP
podman machine ssh $machine 'curl -s http://172.17.144.1:11434/api/tags | head -c 50'
```

**Expected:** JSON response starting with `{"models":[...`

**If this works:** You've found the correct IP to use!

---

## Manual Fix Steps

### Step 1: Note Your Data Volume

The container uses a named volume for data. This will be preserved:
```powershell
podman volume inspect open-webui
```

### Step 2: Get the Gateway IP

```powershell
$machine = (podman system connection list --format "{{.Name}}" | Select-Object -First 1)
$gateway = (podman machine ssh $machine 'ip route show default') -replace '.*via (\d+\.\d+\.\d+\.\d+).*', '$1'
Write-Host "Gateway IP: $gateway"
```

### Step 3: Stop and Remove Old Container

```powershell
podman stop open-webui
podman rm open-webui
```

### Step 4: Create New Container with Correct URL

```powershell
podman run -d `
  -p 3000:8080 `
  -v open-webui:/app/backend/data `
  -e OLLAMA_BASE_URL=http://${gateway}:11434 `
  --name open-webui `
  --restart always `
  ghcr.io/open-webui/open-webui:cuda
```

### Step 5: Verify the Fix

```powershell
# Wait for container to start
Start-Sleep -Seconds 5

# Test connectivity
podman exec open-webui python3 -c "import urllib.request; print('OK:', urllib.request.urlopen('http://${gateway}:11434/api/tags', timeout=5).status)"
```

---

## Using the Debug Script

The `debug-ollama-connection.ps1` script automates all diagnostic and fix steps.

### Diagnose Only (Safe, No Changes)
```powershell
.\debug-ollama-connection.ps1
```

### Diagnose and Fix
```powershell
.\debug-ollama-connection.ps1 -Fix
```

### Sample Output
```
========================================
  Ollama Connection Debugger
========================================

[Phase 1: Diagnosis]
  [PASS] Ollama running on host (6 models)
  [PASS] Container 'open-webui' is running
  [INFO] Current URL: http://host.docker.internal:11434
  [FAIL] Container cannot reach Ollama via configured URL
  [PASS] Gateway IP found: 172.17.144.1
  [PASS] Ollama reachable via gateway

[Phase 2: Analysis]
  Problem: Container using host.docker.internal (169.254.1.2)
  Solution: Use gateway IP http://172.17.144.1:11434

[Phase 3: Fix]
  Recreating container with correct OLLAMA_BASE_URL...
  [PASS] Container recreated successfully
  [PASS] Connectivity verified

========================================
  Fix complete! Open WebUI: http://localhost:3000
========================================
```

---

## Troubleshooting Edge Cases

### Multiple Podman Machines
If you have multiple machines, specify which one:
```powershell
podman machine ssh my-machine-name 'ip route show default'
```

### Firewall Blocking Connection
Ensure Windows Firewall allows Ollama:
```powershell
# Check if Ollama port is listening
netstat -an | Select-String "11434"

# Should show:
# TCP    0.0.0.0:11434    LISTENING
```

### Gateway IP Changes
The WSL2 gateway IP can change after reboot. If connectivity breaks:
1. Run the debug script again: `.\debug-ollama-connection.ps1 -Fix`
2. Or update `OLLAMA_HOST` to always bind correctly

### Using Docker Instead
If you switch to Docker Desktop, the fix isn't needed:
```powershell
# Docker handles host.docker.internal correctly
docker run -d -p 3000:8080 \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  --add-host=host.docker.internal:host-gateway \
  --name open-webui \
  ghcr.io/open-webui/open-webui:cuda
```

---

## Related Files

| File | Purpose |
|------|---------|
| `debug-ollama-connection.ps1` | Automated diagnosis and fix script |
| `test-ollama-stack.ps1` | Full stack test suite |
| `setup-ollama-websearch.ps1` | Main setup script (auto-detects gateway) |
