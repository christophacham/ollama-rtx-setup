<#
.SYNOPSIS
    Ollama Web Search Setup Script
    Enables web search capabilities for local Ollama models

.DESCRIPTION
    This script sets up web search integration for Ollama:
    - Option 1: Open WebUI (recommended) - Beautiful UI with built-in web search
    - Option 2: Perplexica + SearXNG - Full privacy, Perplexity AI alternative
    - Downloads lightweight models optimized for web search tasks
    - Supports both Docker and Podman container runtimes

.NOTES
    Requirements: Docker or Podman, Ollama installed
    Target Hardware: NVIDIA RTX 5090 (32GB VRAM)
#>

param(
    [ValidateSet("OpenWebUI", "Perplexica", "Both")]
    [string]$Setup = "OpenWebUI",
    [switch]$SkipModels,
    [switch]$SkipContainers,
    [switch]$Uninstall,
    [switch]$Help
)

# Script-level container runtime (docker or podman)
$script:ContainerRuntime = $null
$script:ComposeCommand = $null

# Colors for output
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Step { param($step, $msg) Write-Host "`n=== Step $step : $msg ===" -ForegroundColor Magenta }

# Banner
function Show-Banner {
    Write-Host @"

 __          __  _       _____                      _
 \ \        / / | |     / ____|                    | |
  \ \  /\  / /__| |__  | (___   ___  __ _ _ __ ___| |__
   \ \/  \/ / _ \ '_ \  \___ \ / _ \/ _` | '__/ __| '_ \
    \  /\  /  __/ |_) | ____) |  __/ (_| | | | (__| | | |
     \/  \/ \___|_.__/ |_____/ \___|\__,_|_|  \___|_| |_|

        Ollama Web Search Setup for RTX 5090

"@ -ForegroundColor Cyan
}

# Help
function Show-Help {
    Write-Host @"
Usage: .\setup-ollama-websearch.ps1 [options]

Options:
    -Setup <type>    Choose setup type:
                     - OpenWebUI (default) - Beautiful UI with web search
                     - Perplexica - Full privacy with SearXNG
                     - Both - Install both options
    -SkipModels      Skip downloading web search optimized models
    -SkipContainers  Skip container setup (config only)
    -Uninstall       Remove web search containers
    -Help            Show this help message

Examples:
    .\setup-ollama-websearch.ps1                     # Install Open WebUI
    .\setup-ollama-websearch.ps1 -Setup Perplexica   # Install Perplexica
    .\setup-ollama-websearch.ps1 -Setup Both         # Install both
    .\setup-ollama-websearch.ps1 -Uninstall          # Remove containers

Container Runtime:
    Automatically detects Docker or Podman (Docker preferred)

Web Search Options:
    Open WebUI:
      - ChatGPT-like interface
      - 15+ search providers (DuckDuckGo, Google, Brave, etc.)
      - Easy setup, single container
      - Access: http://localhost:3000

    Perplexica:
      - Perplexity AI alternative
      - 100% private with SearXNG
      - Citations and source references
      - Access: http://localhost:3002 (frontend)
                http://localhost:4000 (SearXNG)
"@
}

# Detect container runtime (Docker or Podman)
function Find-ContainerRuntime {
    Write-Step "1" "Detecting Container Runtime"

    # Try Docker first
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($docker) {
        try {
            $dockerInfo = docker info 2>&1
            if ($LASTEXITCODE -eq 0) {
                $script:ContainerRuntime = "docker"
                $script:ComposeCommand = "docker-compose"

                # Check for docker compose (v2) vs docker-compose (v1)
                $dockerComposeV2 = docker compose version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $script:ComposeCommand = "docker compose"
                }

                Write-Success "Docker detected and running"
                Write-Info "Using: $($script:ContainerRuntime) (compose: $($script:ComposeCommand))"
                return $true
            }
        } catch {}
    }

    # Try Podman if Docker not available
    $podman = Get-Command podman -ErrorAction SilentlyContinue
    if ($podman) {
        try {
            $podmanInfo = podman info 2>&1
            if ($LASTEXITCODE -eq 0) {
                $script:ContainerRuntime = "podman"
                $script:ComposeCommand = "podman-compose"

                # Check for podman compose
                $podmanCompose = Get-Command podman-compose -ErrorAction SilentlyContinue
                if (-not $podmanCompose) {
                    # Try podman compose (built-in)
                    $podmanComposeBuiltin = podman compose version 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $script:ComposeCommand = "podman compose"
                    } else {
                        Write-Warn "podman-compose not found. Install with: pip install podman-compose"
                    }
                }

                Write-Success "Podman detected and running"
                Write-Info "Using: $($script:ContainerRuntime) (compose: $($script:ComposeCommand))"
                return $true
            }
        } catch {}
    }

    Write-Err "No container runtime found!"
    Write-Err "Please install Docker Desktop (https://docker.com) or Podman (https://podman.io)"
    return $false
}

# Run container command
function Invoke-Container {
    param([string[]]$Arguments)
    & $script:ContainerRuntime @Arguments
}

# Run compose command
function Invoke-Compose {
    param([string[]]$Arguments)
    if ($script:ComposeCommand -eq "docker compose" -or $script:ComposeCommand -eq "podman compose") {
        & $script:ContainerRuntime compose @Arguments
    } else {
        & $script:ComposeCommand @Arguments
    }
}

# Get host IP for container to reach Ollama
function Get-OllamaHostUrl {
    if ($script:ContainerRuntime -eq "docker") {
        # Docker: host.docker.internal works reliably
        return "http://host.docker.internal:11434"
    } else {
        # Podman: Get gateway IP from the active machine
        try {
            $defaultConn = podman system connection list --format "{{.Name}}" 2>&1 | Select-Object -First 1
            if ($defaultConn) {
                $gateway = podman machine ssh $defaultConn 'ip route show default' 2>&1 | Select-String -Pattern 'via (\d+\.\d+\.\d+\.\d+)' | ForEach-Object { $_.Matches.Groups[1].Value }
                if ($gateway) {
                    Write-Info "Podman host gateway: $gateway"
                    return "http://${gateway}:11434"
                }
            }
        } catch {}
        # Fallback to host.docker.internal (may not work)
        Write-Warn "Could not detect Podman gateway, using host.docker.internal"
        return "http://host.docker.internal:11434"
    }
}

# Check Ollama
function Test-Ollama {
    Write-Step "2" "Checking Ollama"

    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        Write-Success "Ollama is running"

        if ($response.models -and $response.models.Count -gt 0) {
            Write-Info "Found $($response.models.Count) installed models"
        }
        return $true
    } catch {
        Write-Err "Ollama is not running. Please start Ollama first: ollama serve"
        return $false
    }
}

# Configure Ollama for container access
function Set-OllamaContainerAccess {
    Write-Step "3" "Configuring Ollama for Container Access"

    $currentHost = $env:OLLAMA_HOST

    if ($currentHost -eq "0.0.0.0" -or $currentHost -eq "0.0.0.0:11434") {
        Write-Success "Ollama already configured for container access"
        return $true
    }

    Write-Info "Setting OLLAMA_HOST=0.0.0.0 for container access"

    $env:OLLAMA_HOST = "0.0.0.0"
    [System.Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "User")

    Write-Warn "You may need to restart Ollama for changes to take effect"
    Write-Info "Run: ollama serve"

    return $true
}

# Download web search optimized models
function Install-WebSearchModels {
    Write-Step "4" "Installing Web Search Optimized Models"

    $models = @(
        @{ Name = "llama3.1:8b"; Desc = "Fast web search queries"; Size = "~5GB" },
        @{ Name = "mistral:7b"; Desc = "Efficient general web tasks"; Size = "~4GB" }
    )

    Write-Host "`nDownloading lightweight models for fast web searches:" -ForegroundColor Yellow
    foreach ($model in $models) {
        Write-Host "  - $($model.Name) $($model.Size) - $($model.Desc)"
    }
    Write-Host ""

    foreach ($model in $models) {
        Write-Info "Downloading $($model.Name)..."

        try {
            $installed = ollama list 2>&1 | Select-String $model.Name
            if ($installed) {
                Write-Success "$($model.Name) already installed"
                continue
            }

            $process = Start-Process -FilePath "ollama" -ArgumentList "pull $($model.Name)" -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                Write-Success "$($model.Name) downloaded successfully"
            } else {
                Write-Warn "Failed to download $($model.Name), continuing..."
            }
        } catch {
            Write-Warn "Error downloading $($model.Name): $_"
        }
    }

    return $true
}

# Install Open WebUI
function Install-OpenWebUI {
    Write-Step "5" "Installing Open WebUI"

    # Check for NVIDIA GPU first (needed for tag selection)
    $hasGPU = $false
    try {
        $nvidiaSmi = nvidia-smi 2>&1
        if ($LASTEXITCODE -eq 0) {
            $hasGPU = $true
        }
    } catch {}

    # Determine desired image tag
    $desiredTag = if ($hasGPU) { "cuda" } else { "main" }
    $desiredImage = "ghcr.io/open-webui/open-webui:$desiredTag"

    # Check if container already exists
    $existing = Invoke-Container @("ps", "-a", "--filter", "name=open-webui", "--format", "{{.Names}}") 2>&1
    if ($existing -eq "open-webui") {
        # Get current image tag
        $currentImage = Invoke-Container @("inspect", "--format", "{{.Config.Image}}", "open-webui") 2>&1
        Write-Info "Existing container uses: $currentImage"
        Write-Info "Desired image: $desiredImage"

        if ($currentImage -ne $desiredImage) {
            Write-Warn "Container image mismatch detected!"
            Write-Host ""
            Write-Host "  Current: $currentImage" -ForegroundColor Yellow
            Write-Host "  Desired: $desiredImage" -ForegroundColor Green
            Write-Host ""
            $response = Read-Host "Remove existing container and install new image? (y/N)"
            if ($response -eq "y" -or $response -eq "Y") {
                Write-Info "Removing existing container..."
                Invoke-Container @("stop", "open-webui") 2>&1 | Out-Null
                Invoke-Container @("rm", "open-webui") 2>&1 | Out-Null
                Write-Success "Old container removed"
            } else {
                Write-Info "Keeping existing container"
                $running = Invoke-Container @("ps", "--filter", "name=open-webui", "--format", "{{.Names}}") 2>&1
                if ($running -ne "open-webui") {
                    Invoke-Container @("start", "open-webui")
                }
                Write-Success "Open WebUI running at http://localhost:3000"
                return $true
            }
        } else {
            Write-Info "Container already using correct image"
            $running = Invoke-Container @("ps", "--filter", "name=open-webui", "--format", "{{.Names}}") 2>&1
            if ($running -eq "open-webui") {
                Write-Success "Open WebUI is already running at http://localhost:3000"
                return $true
            } else {
                Write-Info "Starting existing container..."
                Invoke-Container @("start", "open-webui")
                Write-Success "Open WebUI started at http://localhost:3000"
                return $true
            }
        }
    }

    # Log GPU status
    if ($hasGPU) {
        Write-Info "NVIDIA GPU detected - using CUDA image"
    } else {
        Write-Info "No GPU detected - using CPU image"
    }
    Write-Info "Using image: $desiredImage"
    Write-Info "Pulling Open WebUI image (this may take a few minutes)..."

    # Get the correct Ollama URL for this container runtime
    $ollamaUrl = Get-OllamaHostUrl
    Write-Info "Ollama URL: $ollamaUrl"

    # Build container run command
    # :cuda tag = CUDA support + connects to external Ollama (no embedded Ollama)
    # :main tag = CPU only + connects to external Ollama
    $containerArgs = @(
        "run", "-d",
        "-p", "3000:8080",
        "-v", "open-webui:/app/backend/data",
        "-e", "OLLAMA_BASE_URL=$ollamaUrl",
        "--name", "open-webui",
        "--restart", "always"
    )

    # Add host gateway for Docker (not needed for Podman with direct IP)
    if ($script:ContainerRuntime -eq "docker") {
        $containerArgs += @("--add-host=host.docker.internal:host-gateway")
        if ($hasGPU) {
            Write-Info "Enabling GPU passthrough for Docker"
            $containerArgs += @("--gpus=all")
        }
    }

    $containerArgs += @($desiredImage)

    try {
        $result = Invoke-Container $containerArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Open WebUI installed successfully!"
            Write-Host ""
            Write-Host "  Access Open WebUI at: " -NoNewline
            Write-Host "http://localhost:3000" -ForegroundColor Green
            Write-Host "  Image: $desiredImage (no embedded Ollama)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  To enable web search:" -ForegroundColor Yellow
            Write-Host "  1. Open http://localhost:3000"
            Write-Host "  2. Create an account (first user becomes admin)"
            Write-Host "  3. Go to Settings > Web Search"
            Write-Host "  4. Enable and choose a provider (DuckDuckGo is free)"
            Write-Host ""
            return $true
        } else {
            Write-Err "Failed to start Open WebUI: $result"
            return $false
        }
    } catch {
        Write-Err "Container error: $_"
        return $false
    }
}

# Create Perplexica docker-compose file
function New-PerplexicaCompose {
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }

    $composePath = Join-Path $scriptDir "docker-compose-perplexica.yml"

    $composeContent = @"
version: '3.8'

services:
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    ports:
      - "4000:8080"
    volumes:
      - ./searxng:/etc/searxng
    environment:
      - SEARXNG_BASE_URL=http://localhost:4000
    restart: unless-stopped
    networks:
      - perplexica-network

  perplexica-backend:
    image: itzcrazykns1337/perplexica-backend:main
    container_name: perplexica-backend
    ports:
      - "3001:3001"
    volumes:
      - ./perplexica/config.toml:/app/config.toml
      - ./perplexica/data:/app/data
    depends_on:
      - searxng
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
    networks:
      - perplexica-network

  perplexica-frontend:
    image: itzcrazykns1337/perplexica-frontend:main
    container_name: perplexica-frontend
    ports:
      - "3002:3000"
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:3001
      - NEXT_PUBLIC_WS_URL=ws://localhost:3001
    depends_on:
      - perplexica-backend
    restart: unless-stopped
    networks:
      - perplexica-network

networks:
  perplexica-network:
    driver: bridge
"@

    $composeContent | Out-File $composePath -Encoding utf8
    Write-Success "Created docker-compose-perplexica.yml"
    return $composePath
}

# Create Perplexica config
function New-PerplexicaConfig {
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }

    $perplexicaDir = Join-Path $scriptDir "perplexica"
    $searxngDir = Join-Path $scriptDir "searxng"

    New-Item -ItemType Directory -Path $perplexicaDir -Force | Out-Null
    New-Item -ItemType Directory -Path $searxngDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $perplexicaDir "data") -Force | Out-Null

    $configPath = Join-Path $perplexicaDir "config.toml"
    $configContent = @"
[GENERAL]
PORT = 3001
SIMILARITY_MEASURE = "cosine"

[API_KEYS]
OPENAI = ""
GROQ = ""
ANTHROPIC = ""

[API_ENDPOINTS]
SEARXNG = "http://searxng:8080"
OLLAMA = "http://host.docker.internal:11434"
"@
    $configContent | Out-File $configPath -Encoding utf8
    Write-Success "Created perplexica/config.toml"

    $searxngSettingsPath = Join-Path $searxngDir "settings.yml"
    $searxngSettings = @"
use_default_settings: true

server:
  secret_key: "$(New-Guid)"
  bind_address: "0.0.0.0"

search:
  safe_search: 0
  autocomplete: "duckduckgo"
  default_lang: "en"

engines:
  - name: duckduckgo
    engine: duckduckgo
    disabled: false
  - name: google
    engine: google
    disabled: false
  - name: bing
    engine: bing
    disabled: false
  - name: brave
    engine: brave
    disabled: false
  - name: wikipedia
    engine: wikipedia
    disabled: false
  - name: github
    engine: github
    disabled: false
  - name: stackoverflow
    engine: stackoverflow
    disabled: false
"@
    $searxngSettings | Out-File $searxngSettingsPath -Encoding utf8
    Write-Success "Created searxng/settings.yml"

    return $true
}

# Install Perplexica
function Install-Perplexica {
    Write-Step "5" "Installing Perplexica + SearXNG"

    $existing = Invoke-Container @("ps", "--filter", "name=perplexica", "--format", "{{.Names}}") 2>&1
    if ($existing) {
        Write-Success "Perplexica is already running"
        Write-Host "  Frontend: http://localhost:3002"
        Write-Host "  SearXNG:  http://localhost:4000"
        return $true
    }

    Write-Info "Creating configuration files..."
    New-PerplexicaConfig | Out-Null

    $composePath = New-PerplexicaCompose

    Write-Info "Starting Perplexica stack (this may take a few minutes)..."
    Write-Info "Using: $($script:ComposeCommand)"

    try {
        if ($script:ComposeCommand -eq "docker compose" -or $script:ComposeCommand -eq "podman compose") {
            $result = & $script:ContainerRuntime compose -f $composePath up -d 2>&1
        } else {
            $result = & $script:ComposeCommand -f $composePath up -d 2>&1
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Perplexica installed successfully!"
            Write-Host ""
            Write-Host "  Access Perplexica at: " -NoNewline
            Write-Host "http://localhost:3002" -ForegroundColor Green
            Write-Host "  SearXNG (direct): " -NoNewline
            Write-Host "http://localhost:4000" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Configuration:" -ForegroundColor Yellow
            Write-Host "  1. Open http://localhost:3002"
            Write-Host "  2. Select your Ollama model (qwen3:32b recommended)"
            Write-Host "  3. Start searching with AI-powered answers!"
            Write-Host ""
            return $true
        } else {
            Write-Err "Failed to start Perplexica: $result"
            return $false
        }
    } catch {
        Write-Err "Compose error: $_"
        return $false
    }
}

# Uninstall containers
function Remove-WebSearch {
    Write-Step "X" "Removing Web Search Containers"

    Write-Info "Stopping and removing Open WebUI..."
    Invoke-Container @("stop", "open-webui") 2>&1 | Out-Null
    Invoke-Container @("rm", "open-webui") 2>&1 | Out-Null

    Write-Info "Stopping and removing Perplexica stack..."
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }
    $composePath = Join-Path $scriptDir "docker-compose-perplexica.yml"

    if (Test-Path $composePath) {
        if ($script:ComposeCommand -eq "docker compose" -or $script:ComposeCommand -eq "podman compose") {
            & $script:ContainerRuntime compose -f $composePath down 2>&1 | Out-Null
        } else {
            & $script:ComposeCommand -f $composePath down 2>&1 | Out-Null
        }
    }

    Invoke-Container @("stop", "searxng", "perplexica-backend", "perplexica-frontend") 2>&1 | Out-Null
    Invoke-Container @("rm", "searxng", "perplexica-backend", "perplexica-frontend") 2>&1 | Out-Null

    Write-Success "Web search containers removed"
    Write-Info "Note: Volumes preserved. Use '$($script:ContainerRuntime) volume prune' to remove data."

    return $true
}

# Show completion
function Show-Complete {
    param([string]$SetupType)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  WEB SEARCH SETUP COMPLETE!           " -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Container Runtime: $($script:ContainerRuntime)" -ForegroundColor Gray
    Write-Host ""

    switch ($SetupType) {
        "OpenWebUI" {
            Write-Host "Open WebUI: " -NoNewline
            Write-Host "http://localhost:3000" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Quick Start:" -ForegroundColor Yellow
            Write-Host "  1. Open http://localhost:3000"
            Write-Host "  2. Create account (first user = admin)"
            Write-Host "  3. Settings > Web Search > Enable"
            Write-Host "  4. Choose DuckDuckGo (no API key needed)"
        }
        "Perplexica" {
            Write-Host "Perplexica: " -NoNewline
            Write-Host "http://localhost:3002" -ForegroundColor Cyan
            Write-Host "SearXNG:    " -NoNewline
            Write-Host "http://localhost:4000" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Quick Start:" -ForegroundColor Yellow
            Write-Host "  1. Open http://localhost:3002"
            Write-Host "  2. Select Ollama model (qwen3:32b)"
            Write-Host "  3. Start searching!"
        }
        "Both" {
            Write-Host "Open WebUI: " -NoNewline
            Write-Host "http://localhost:3000" -ForegroundColor Cyan
            Write-Host "Perplexica: " -NoNewline
            Write-Host "http://localhost:3002" -ForegroundColor Cyan
            Write-Host "SearXNG:    " -NoNewline
            Write-Host "http://localhost:4000" -ForegroundColor Cyan
        }
    }

    Write-Host ""
    Write-Host "Recommended Models for Web Search:" -ForegroundColor Yellow
    Write-Host "  - qwen3:32b      (best synthesis)"
    Write-Host "  - deepseek-r1:32b (deep reasoning)"
    Write-Host "  - llama3.1:8b    (fast queries)"
    Write-Host ""
}

# Main
function Main {
    Show-Banner

    if ($Help) {
        Show-Help
        return
    }

    # Detect container runtime first
    if (-not $SkipContainers) {
        if (-not (Find-ContainerRuntime)) { return }
    }

    if ($Uninstall) {
        Remove-WebSearch
        return
    }

    if (-not (Test-Ollama)) { return }

    Set-OllamaContainerAccess | Out-Null

    if (-not $SkipModels) {
        Install-WebSearchModels | Out-Null
    }

    if (-not $SkipContainers) {
        switch ($Setup) {
            "OpenWebUI" {
                Install-OpenWebUI | Out-Null
            }
            "Perplexica" {
                Install-Perplexica | Out-Null
            }
            "Both" {
                Install-OpenWebUI | Out-Null
                Install-Perplexica | Out-Null
            }
        }
    }

    Show-Complete -SetupType $Setup
}

# Run
Main
