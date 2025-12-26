---
sidebar_position: 2
---

# Network Architecture

Understanding container networking, especially with Podman on Windows.

## The Challenge

Containers need to reach Ollama running on Windows. This should be simple, but different container runtimes handle it differently.

## Docker Desktop

Docker Desktop handles this elegantly:

```
┌─────────────────────────────────────────────────┐
│                WINDOWS HOST                      │
│                                                  │
│   Ollama ─────────────── localhost:11434        │
│      │                                          │
│      │  (Docker magic: host-gateway routing)    │
│      │                                          │
├──────┼──────────────────────────────────────────┤
│      │         DOCKER CONTAINER                 │
│      │                                          │
│      └──► host.docker.internal:11434  ✓ WORKS  │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Why it works:** Docker Desktop runs a special VM with proper NAT routing. `host.docker.internal` resolves to an IP that correctly routes to Windows.

## Podman on WSL2

Podman has a different architecture:

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
│   Gateway IP ─────────────────────── 172.17.x.1  ✓ WORKS   │
│        │                                                    │
├────────┼────────────────────────────────────────────────────┤
│        │              CONTAINER                             │
│        │                                                    │
│        ├── host.docker.internal ──── 169.254.1.2  ✗ FAILS  │
│        │                                                    │
│        └── 172.17.x.1:11434 ────────────────────  ✓ WORKS  │
└─────────────────────────────────────────────────────────────┘
```

**Why it fails:** Podman on WSL2 sets `host.docker.internal` to `169.254.1.2` (a link-local address). This doesn't route to Windows - it goes nowhere.

**The fix:** Use the WSL2 gateway IP instead.

## Finding the Gateway IP

The Podman machine has a default gateway that routes to Windows:

```powershell
# Get your Podman machine name
podman system connection list

# SSH in and check the route
podman machine ssh gpu-machine 'ip route show default'

# Output: default via 172.17.144.1 dev eth0 proto kernel
#                     ^^^^^^^^^^^^
#                     This is your gateway
```

## Automated Detection

Our scripts detect the gateway automatically:

```powershell
# From setup-ollama-websearch.ps1
function Get-OllamaHostUrl {
    if ($script:ContainerRuntime -eq "docker") {
        return "http://host.docker.internal:11434"
    } else {
        # Podman: Get gateway IP from the active machine
        $defaultConn = podman system connection list --format "{{.Name}}" | Select-Object -First 1
        $routeOutput = podman machine ssh $defaultConn 'ip route show default'
        if ($routeOutput -match 'via (\d+\.\d+\.\d+\.\d+)') {
            return "http://$($Matches[1]):11434"
        }
    }
}
```

## Port Forwarding

Containers expose ports to the Windows host:

```
Container Internal     Windows Host
──────────────────     ────────────
8080 (WebUI)      ──►  3000
3000 (Perplexica) ──►  3002
8080 (SearXNG)    ──►  4000
```

Configured via `-p` flag:
```powershell
podman run -p 3000:8080 ...  # Host:Container
```

## DNS Resolution

### Inside Containers

| Hostname | Docker | Podman |
|----------|--------|--------|
| `host.docker.internal` | Windows IP | 169.254.1.2 (broken) |
| `localhost` | Container itself | Container itself |
| `gateway.docker.internal` | Gateway | Not available |

### Verification

```powershell
# Check DNS resolution from inside container
podman exec open-webui getent hosts host.docker.internal

# Test connectivity
podman exec open-webui python3 -c "
import urllib.request
print(urllib.request.urlopen('http://172.17.144.1:11434/api/tags').read()[:50])
"
```

## Firewall Considerations

Windows Firewall must allow traffic from WSL2:

```powershell
# Check if Ollama port is listening
netstat -an | Select-String "11434"

# Should show:
# TCP    0.0.0.0:11434    LISTENING
```

If blocked, add firewall rule:
```powershell
New-NetFirewallRule -DisplayName "Ollama API" -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow
```

## IP Persistence

### The Problem

The WSL2 gateway IP can change after:
- Windows reboot
- Podman machine restart
- WSL2 restart

### Solutions

1. **Re-run debug script after reboot:**
```powershell
.\debug-ollama-connection.ps1 -Fix
```

2. **Use dynamic detection in scripts** (our approach)

3. **Set static IP** (advanced, not recommended)

## Multi-Container Communication

Containers on the same network can communicate directly:

```
┌─────────────────────────────────────────────┐
│           perplexica-network                │
│                                             │
│  ┌─────────────┐      ┌─────────────┐      │
│  │  perplexica │ ───► │   searxng   │      │
│  │  backend    │      │             │      │
│  └─────────────┘      └─────────────┘      │
│        │                                    │
│        │  http://searxng:8080              │
│        │  (Docker DNS resolves container)  │
│                                             │
└─────────────────────────────────────────────┘
```

## Debugging Commands

### Check Container Network

```powershell
# Container IP address
podman inspect open-webui --format '{{.NetworkSettings.IPAddress}}'

# All network settings
podman inspect open-webui --format '{{json .NetworkSettings}}' | ConvertFrom-Json

# Container's view of hosts
podman exec open-webui cat /etc/hosts
```

### Test Connectivity

```powershell
# From container to Ollama
podman exec open-webui curl -s http://172.17.144.1:11434/api/tags

# From Windows to container
curl http://localhost:3000

# Container to container (if on same network)
podman exec perplexica-backend curl http://searxng:8080
```

### Network Inspection

```powershell
# List networks
podman network ls

# Inspect network
podman network inspect perplexica-network

# Check routes inside container
podman exec open-webui ip route
```

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `Connection refused` | Wrong IP | Use gateway IP |
| `Host not found` | DNS issue | Use IP directly |
| `Timeout` | Firewall | Add firewall rule |
| `Connection reset` | Ollama not running | Start Ollama |

See [Troubleshooting Podman](/troubleshooting/podman-ollama) for detailed diagnostics.
