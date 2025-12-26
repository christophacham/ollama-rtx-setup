---
sidebar_position: 2
---

# Common Issues

Frequently encountered problems and their solutions.

## Installation Issues

### "Ollama command not found"

**Problem:** PowerShell doesn't recognize `ollama` command.

**Solutions:**
1. Restart PowerShell after installation
2. Check PATH:
   ```powershell
   $env:PATH -split ';' | Select-String ollama
   ```
3. Reinstall Ollama from [ollama.ai](https://ollama.ai)

### "CUDA not available"

**Problem:** Ollama uses CPU instead of GPU.

**Check:**
```powershell
nvidia-smi
```

**Solutions:**
1. Update NVIDIA drivers (525.60+ for CUDA 12)
2. Verify GPU is detected:
   ```powershell
   nvidia-smi --query-gpu=name --format=csv
   ```
3. Reinstall CUDA toolkit if needed

### "Access denied" during setup

**Problem:** Scripts can't create files or modify settings.

**Solution:** Run PowerShell as Administrator:
```powershell
Start-Process powershell -Verb RunAs
```

## Model Issues

### "Model not found"

**Problem:** `ollama run modelname` fails.

**Solutions:**
1. Check exact model name:
   ```powershell
   ollama list
   ```
2. Pull the model first:
   ```powershell
   ollama pull qwen3:32b
   ```
3. Check for typos (e.g., `qwen3:32b` not `qwen-3:32b`)

### "Out of memory"

**Problem:** CUDA out of memory error during inference.

**Solutions:**
1. Use smaller quantization:
   ```powershell
   ollama pull qwen3:32b-q4_K_M  # Instead of default
   ```
2. Reduce context window:
   ```powershell
   ollama run qwen3:32b --num-ctx 2048
   ```
3. Unload other models:
   ```powershell
   ollama ps  # Check loaded models
   ollama stop other-model
   ```
4. Use a smaller model

### "Model loads slowly"

**Problem:** First response takes 10+ seconds.

**Causes:**
- Model loading from disk
- Cold start after `OLLAMA_KEEP_ALIVE` timeout

**Solutions:**
1. Increase keep-alive:
   ```powershell
   $env:OLLAMA_KEEP_ALIVE = "30m"
   ```
2. Use faster storage (NVMe SSD)
3. Preload model:
   ```powershell
   ollama run qwen3:32b ""  # Empty prompt just loads
   ```

### "Model gives wrong answers"

**Problem:** Output is incorrect or nonsensical.

**Solutions:**
1. Lower temperature for factual tasks:
   ```powershell
   ollama run qwen3:32b --temperature 0.3
   ```
2. Use appropriate model (coding model for code, etc.)
3. Check if model is corrupted:
   ```powershell
   ollama rm qwen3:32b
   ollama pull qwen3:32b
   ```

## Container Issues

### "Container won't start"

**Problem:** `docker/podman run` fails.

**Check:**
```powershell
# Docker
docker info

# Podman
podman info
```

**Solutions:**
1. Start container runtime:
   - Docker: Open Docker Desktop
   - Podman: `podman machine start`
2. Check for port conflicts:
   ```powershell
   netstat -an | Select-String "3000"
   ```

### "Open WebUI shows no models"

**Problem:** WebUI loads but no Ollama models appear.

**Causes:**
- Container can't reach Ollama
- Wrong `OLLAMA_BASE_URL`

**Solutions:**
1. Check Ollama is running:
   ```powershell
   curl http://localhost:11434/api/tags
   ```
2. For Podman, see [Podman Connectivity](/troubleshooting/podman-ollama)
3. Verify environment variable:
   ```powershell
   podman inspect open-webui --format '{{range .Config.Env}}{{println .}}{{end}}'
   ```

### "Permission denied" in container

**Problem:** Container logs show permission errors.

**Solutions:**
1. Check volume ownership:
   ```powershell
   docker volume inspect open-webui
   ```
2. Run as root (temporary fix):
   ```powershell
   docker run --user root ...
   ```

## Network Issues

### "Connection refused"

**Problem:** Can't connect to services.

**Checklist:**
1. Is the service running?
   ```powershell
   ollama ps        # Ollama
   docker ps        # Containers
   ```
2. Is the port open?
   ```powershell
   netstat -an | Select-String "11434"
   ```
3. Is firewall blocking?
   ```powershell
   Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*Ollama*"}
   ```

### "Timeout" errors

**Problem:** Requests take too long and fail.

**Solutions:**
1. Check if Ollama is under load:
   ```powershell
   ollama ps
   ```
2. Increase timeout in client
3. Check network connectivity:
   ```powershell
   Test-NetConnection localhost -Port 11434
   ```

### "Slow responses"

**Problem:** Inference is slower than expected.

**Check:**
```powershell
# GPU utilization
nvidia-smi -l 1
```

**Solutions:**
1. Ensure GPU is being used (not CPU)
2. Check for thermal throttling (keep GPU < 80°C)
3. Close other GPU-intensive applications
4. Use quantized models for speed

## Performance Issues

### "GPU not fully utilized"

**Problem:** `nvidia-smi` shows low GPU usage.

**Causes:**
- Small batch size
- CPU bottleneck during prompt processing

**Solutions:**
1. Increase batch size:
   ```powershell
   $env:OLLAMA_BATCH_SIZE = 512
   ```
2. Use longer prompts to keep GPU busy
3. Enable parallel requests:
   ```powershell
   $env:OLLAMA_NUM_PARALLEL = 4
   ```

### "System becomes unresponsive"

**Problem:** Computer freezes during inference.

**Causes:**
- All RAM consumed
- GPU driver crash

**Solutions:**
1. Limit CPU layers:
   ```powershell
   $env:OLLAMA_NUM_CPU = 0  # GPU only
   ```
2. Use smaller model
3. Update GPU drivers
4. Add more system RAM

## Web Search Issues

### "Search returns no results"

**Problem:** Web search feature doesn't work.

**For Open WebUI:**
1. Check search is enabled (Settings → Web Search)
2. Verify API key (if required by provider)
3. Try different provider (DuckDuckGo needs no key)

**For Perplexica:**
1. Check SearXNG is running:
   ```powershell
   curl http://localhost:4000
   ```
2. Verify engines are enabled in `searxng/settings.yml`

### "SearXNG returns empty"

**Problem:** SearXNG queries return nothing.

**Solutions:**
1. Some engines may be rate-limited
2. Try direct search:
   ```powershell
   curl "http://localhost:4000/search?q=test&format=json"
   ```
3. Enable more engines in settings

## Still Stuck?

### Collect Debug Information

```powershell
# System info
nvidia-smi
ollama --version
docker --version 2>$null
podman --version 2>$null

# Ollama status
ollama ps
ollama list

# Container status
docker ps -a 2>$null
podman ps -a 2>$null

# Network
netstat -an | Select-String "11434|3000|3002|4000"
```

### Run Test Suite

```powershell
.\test-ollama-stack.ps1 -Full
```

### Check Logs

```powershell
# Ollama logs (if running as service)
Get-Content "$env:USERPROFILE\.ollama\logs\server.log" -Tail 50

# Container logs
docker logs open-webui --tail 50
```
