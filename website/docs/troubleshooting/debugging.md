---
sidebar_position: 3
---

# Debugging Guide

How to use the diagnostic tools and scripts for troubleshooting.

## Debug Scripts

### debug-ollama-connection.ps1

Comprehensive diagnostic tool for Podman + Ollama connectivity issues.

#### Usage

```powershell
# Diagnose only
.\debug-ollama-connection.ps1

# Diagnose and fix automatically
.\debug-ollama-connection.ps1 -Fix

# Focus on specific container
.\debug-ollama-connection.ps1 -ContainerName "open-webui" -Fix
```

#### What It Checks

1. **Ollama Status**
   - Is Ollama running?
   - Is the API responding?
   - What models are loaded?

2. **Container Runtime**
   - Docker or Podman detected?
   - Is the runtime running?

3. **Network Connectivity**
   - What IP is `host.docker.internal`?
   - What is the gateway IP?
   - Can containers reach Ollama?

4. **Container Configuration**
   - What `OLLAMA_BASE_URL` is set?
   - Is it using the correct IP?

#### Output Example

```
=== Ollama + Container Connectivity Debug ===

[1/5] Checking Ollama status...
  [OK] Ollama is running (PID: 12345)
  [OK] API responding at http://localhost:11434

[2/5] Detecting container runtime...
  [OK] Using Podman

[3/5] Checking DNS resolution...
  [WARN] host.docker.internal resolves to 169.254.1.2 (link-local)
  [INFO] This IP won't route to Windows host

[4/5] Finding gateway IP...
  [OK] Gateway IP: 172.17.144.1
  [OK] Ollama reachable at http://172.17.144.1:11434

[5/5] Checking container configuration...
  [WARN] open-webui using http://host.docker.internal:11434
  [FIX] Should use http://172.17.144.1:11434

=== Recommendation ===
Run with -Fix to recreate container with correct URL
```

### test-ollama-stack.ps1

End-to-end test suite for the complete stack.

#### Usage

```powershell
# Quick tests
.\test-ollama-stack.ps1

# Full test suite
.\test-ollama-stack.ps1 -Full

# Verbose output
.\test-ollama-stack.ps1 -Full -Verbose
```

#### Test Categories

| Test | What It Checks |
|------|---------------|
| **Ollama** | Installation, service, API |
| **Models** | At least one model available |
| **Containers** | Runtime, running containers |
| **Network** | Port bindings, connectivity |
| **GPU** | CUDA availability, VRAM |

#### Full Test Mode

The `-Full` flag adds:
- Model inference test (generates tokens)
- Container health checks
- Cross-container network tests
- GPU utilization verification

## Manual Debugging

### Check Ollama

```powershell
# Is Ollama running?
Get-Process ollama -ErrorAction SilentlyContinue

# Is API responding?
curl http://localhost:11434/api/tags

# What models are loaded?
ollama ps

# Ollama version
ollama --version

# Server logs (if running as service)
Get-Content "$env:USERPROFILE\.ollama\logs\server.log" -Tail 50
```

### Check GPU

```powershell
# GPU info
nvidia-smi

# Continuous monitoring
nvidia-smi -l 1

# Just GPU name and VRAM
nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv

# CUDA version
nvcc --version
```

### Check Containers

```powershell
# Running containers
podman ps
docker ps

# All containers (including stopped)
podman ps -a

# Container logs
podman logs open-webui --tail 100

# Follow logs in real-time
podman logs -f open-webui

# Container environment
podman inspect open-webui --format '{{range .Config.Env}}{{println .}}{{end}}'

# Container network
podman inspect open-webui --format '{{json .NetworkSettings}}'
```

### Check Network

```powershell
# Ports in use
netstat -an | Select-String "11434|3000|3002|4000"

# Test Ollama from host
Test-NetConnection localhost -Port 11434

# Test from inside container
podman exec open-webui python3 -c "
import urllib.request
print(urllib.request.urlopen('http://172.17.144.1:11434/api/tags', timeout=5).read()[:100])
"

# DNS resolution in container
podman exec open-webui getent hosts host.docker.internal

# Container's routing table
podman exec open-webui ip route
```

### Check Firewall

```powershell
# Is port open in firewall?
Get-NetFirewallRule | Where-Object {
    $_.Direction -eq 'Inbound' -and
    $_.Enabled -eq $true
} | Get-NetFirewallPortFilter | Where-Object {
    $_.LocalPort -eq 11434
}

# Add rule if missing
New-NetFirewallRule -DisplayName "Ollama API" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 11434 `
    -Action Allow
```

## Common Debug Scenarios

### Scenario 1: "Ollama not responding"

```powershell
# Step 1: Check if running
Get-Process ollama

# Step 2: If not running, start it
ollama serve

# Step 3: Check API
curl http://localhost:11434/api/tags

# Step 4: Check logs for errors
Get-Content "$env:USERPROFILE\.ollama\logs\server.log" -Tail 100
```

### Scenario 2: "Container can't reach Ollama"

```powershell
# Step 1: Get correct IP
$machine = podman system connection list --format "{{.Name}}" | Select-Object -First 1
podman machine ssh $machine 'ip route show default'
# Note the gateway IP (e.g., 172.17.144.1)

# Step 2: Test from container
podman exec open-webui curl http://172.17.144.1:11434/api/tags

# Step 3: If works, recreate container with correct URL
podman stop open-webui
podman rm open-webui
podman run -d -p 3000:8080 `
  -v open-webui:/app/backend/data `
  -e OLLAMA_BASE_URL=http://172.17.144.1:11434 `
  --name open-webui `
  ghcr.io/open-webui/open-webui:cuda
```

### Scenario 3: "Slow inference"

```powershell
# Step 1: Check GPU usage
nvidia-smi -l 1

# Step 2: If GPU not being used, check Ollama sees it
$env:OLLAMA_DEBUG = 1
ollama run qwen3:32b "test"

# Step 3: Check for thermal throttling (keep below 80°C)
nvidia-smi --query-gpu=temperature.gpu --format=csv -l 1

# Step 4: Check if model fits in VRAM
# Look for "offloading X layers to CPU" in output
```

### Scenario 4: "Out of memory"

```powershell
# Step 1: Check current memory usage
nvidia-smi

# Step 2: Unload other models
ollama ps
ollama stop other-model-name

# Step 3: Try smaller quantization
ollama rm qwen3:32b
ollama pull qwen3:32b-q4_K_M

# Step 4: Reduce context window
ollama run qwen3:32b --num-ctx 2048
```

## Log Locations

| Component | Log Location |
|-----------|-------------|
| **Ollama** | `~\.ollama\logs\server.log` |
| **Docker Desktop** | Docker Desktop → Troubleshoot → Get Support |
| **Podman** | `podman events` |
| **Open WebUI** | `podman logs open-webui` |
| **Perplexica** | `podman logs perplexica-backend` |
| **SearXNG** | `podman logs searxng` |

## Environment Variables for Debug

```powershell
# Enable Ollama debug logging
$env:OLLAMA_DEBUG = 1

# Show model loading details
$env:OLLAMA_MODELS = "$env:USERPROFILE\.ollama\models"

# Force CPU-only (for testing)
$env:CUDA_VISIBLE_DEVICES = ""

# Verbose container output
podman --log-level debug run ...
```

## Getting Help

If you're still stuck after debugging:

1. **Collect information:**
```powershell
# System info dump
nvidia-smi > debug-info.txt
ollama --version >> debug-info.txt
docker --version 2>>debug-info.txt
podman --version 2>>debug-info.txt
ollama ps >> debug-info.txt
ollama list >> debug-info.txt
podman ps -a >> debug-info.txt
netstat -an | Select-String "11434|3000" >> debug-info.txt
```

2. **Check existing issues:**
   - [Ollama GitHub Issues](https://github.com/ollama/ollama/issues)
   - [Open WebUI GitHub Issues](https://github.com/open-webui/open-webui/issues)

3. **Open an issue** with:
   - Your `debug-info.txt`
   - Steps to reproduce
   - Expected vs actual behavior
