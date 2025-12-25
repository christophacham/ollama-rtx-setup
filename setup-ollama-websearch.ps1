<#
.SYNOPSIS
    Ollama Web Search Setup Script
    Enables web search capabilities for local Ollama models

.DESCRIPTION
    This script sets up web search integration for Ollama:
    - Option 1: Open WebUI (recommended) - Beautiful UI with built-in web search
    - Option 2: Perplexica + SearXNG - Full privacy, Perplexity AI alternative
    - Downloads lightweight models optimized for web search tasks
    - Configures Docker containers and networking

.NOTES
    Requirements: Docker Desktop, Ollama installed
    Target Hardware: NVIDIA RTX 5090 (32GB VRAM)
#>

param(
    [ValidateSet("OpenWebUI", "Perplexica", "Both")]
    [string]$Setup = "OpenWebUI",
    [switch]$SkipModels,
    [switch]$SkipDocker,
    [switch]$Uninstall,
    [switch]$Help
)

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
    -SkipDocker      Skip Docker container setup (config only)
    -Uninstall       Remove web search containers
    -Help            Show this help message

Examples:
    .\setup-ollama-websearch.ps1                     # Install Open WebUI
    .\setup-ollama-websearch.ps1 -Setup Perplexica   # Install Perplexica
    .\setup-ollama-websearch.ps1 -Setup Both         # Install both
    .\setup-ollama-websearch.ps1 -Uninstall          # Remove containers

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
      - Access: http://localhost:3000 (frontend)
                http://localhost:4000 (SearXNG)
"@
}

# Check Docker
function Test-Docker {
    Write-Step "1" "Checking Docker"

    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        Write-Err "Docker not found. Please install Docker Desktop from https://docker.com"
        return $false
    }

    try {
        $dockerInfo = docker info 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Docker is not running. Please start Docker Desktop."
            return $false
        }
        Write-Success "Docker is installed and running"
        return $true
    } catch {
        Write-Err "Docker error: $_"
        return $false
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

# Configure Ollama for Docker access
function Set-OllamaDockerAccess {
    Write-Step "3" "Configuring Ollama for Docker Access"

    # Check if OLLAMA_HOST is set
    $currentHost = $env:OLLAMA_HOST

    if ($currentHost -eq "0.0.0.0" -or $currentHost -eq "0.0.0.0:11434") {
        Write-Success "Ollama already configured for Docker access"
        return $true
    }

    Write-Info "Setting OLLAMA_HOST=0.0.0.0 for Docker container access"

    # Set for current session
    $env:OLLAMA_HOST = "0.0.0.0"

    # Set permanently for user
    [System.Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "User")

    Write-Warn "You may need to restart Ollama for changes to take effect"
    Write-Info "Run: ollama serve"

    return $true
}

# Download web search optimized models
function Install-WebSearchModels {
    Write-Step "4" "Installing Web Search Optimized Models"

    # Models good for web search (smaller for speed, or larger for quality)
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
            # Check if already installed
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

    # Check if already running
    $existing = docker ps -a --filter "name=open-webui" --format "{{.Names}}" 2>&1
    if ($existing -eq "open-webui") {
        Write-Info "Open WebUI container already exists"

        $running = docker ps --filter "name=open-webui" --format "{{.Names}}" 2>&1
        if ($running -eq "open-webui") {
            Write-Success "Open WebUI is already running at http://localhost:3000"
            return $true
        } else {
            Write-Info "Starting existing container..."
            docker start open-webui
            Write-Success "Open WebUI started at http://localhost:3000"
            return $true
        }
    }

    Write-Info "Pulling Open WebUI image (this may take a few minutes)..."

    # Check for NVIDIA GPU
    $hasGPU = $false
    try {
        $nvidiaSmi = nvidia-smi 2>&1
        if ($LASTEXITCODE -eq 0) {
            $hasGPU = $true
            Write-Info "NVIDIA GPU detected - enabling GPU support"
        }
    } catch {}

    # Build docker run command
    if ($hasGPU) {
        $dockerCmd = @(
            "run", "-d",
            "-p", "3000:8080",
            "--gpus=all",
            "-v", "ollama:/root/.ollama",
            "-v", "open-webui:/app/backend/data",
            "--add-host=host.docker.internal:host-gateway",
            "--name", "open-webui",
            "--restart", "always",
            "ghcr.io/open-webui/open-webui:ollama"
        )
    } else {
        $dockerCmd = @(
            "run", "-d",
            "-p", "3000:8080",
            "-v", "ollama:/root/.ollama",
            "-v", "open-webui:/app/backend/data",
            "--add-host=host.docker.internal:host-gateway",
            "--name", "open-webui",
            "--restart", "always",
            "ghcr.io/open-webui/open-webui:ollama"
        )
    }

    try {
        $result = & docker @dockerCmd 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Open WebUI installed successfully!"
            Write-Host ""
            Write-Host "  Access Open WebUI at: " -NoNewline
            Write-Host "http://localhost:3000" -ForegroundColor Green
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
        Write-Err "Docker error: $_"
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

    # Create directories
    $perplexicaDir = Join-Path $scriptDir "perplexica"
    $searxngDir = Join-Path $scriptDir "searxng"

    New-Item -ItemType Directory -Path $perplexicaDir -Force | Out-Null
    New-Item -ItemType Directory -Path $searxngDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $perplexicaDir "data") -Force | Out-Null

    # Perplexica config
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

    # SearXNG settings
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

    # Check if already running
    $existing = docker ps --filter "name=perplexica" --format "{{.Names}}" 2>&1
    if ($existing) {
        Write-Success "Perplexica is already running"
        Write-Host "  Frontend: http://localhost:3002"
        Write-Host "  SearXNG:  http://localhost:4000"
        return $true
    }

    # Create config files
    Write-Info "Creating configuration files..."
    New-PerplexicaConfig | Out-Null

    # Create docker-compose file
    $composePath = New-PerplexicaCompose

    Write-Info "Starting Perplexica stack (this may take a few minutes)..."

    try {
        $result = docker-compose -f $composePath up -d 2>&1
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
        Write-Err "Docker Compose error: $_"
        return $false
    }
}

# Uninstall containers
function Remove-WebSearch {
    Write-Step "X" "Removing Web Search Containers"

    Write-Info "Stopping and removing Open WebUI..."
    docker stop open-webui 2>&1 | Out-Null
    docker rm open-webui 2>&1 | Out-Null

    Write-Info "Stopping and removing Perplexica stack..."
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }
    $composePath = Join-Path $scriptDir "docker-compose-perplexica.yml"

    if (Test-Path $composePath) {
        docker-compose -f $composePath down 2>&1 | Out-Null
    }

    docker stop searxng perplexica-backend perplexica-frontend 2>&1 | Out-Null
    docker rm searxng perplexica-backend perplexica-frontend 2>&1 | Out-Null

    Write-Success "Web search containers removed"
    Write-Info "Note: Docker volumes preserved. Use 'docker volume prune' to remove data."

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
    Write-Host "Documentation: docs/OLLAMA_SETUP.md" -ForegroundColor Gray
    Write-Host ""
}

# Main
function Main {
    Show-Banner

    if ($Help) {
        Show-Help
        return
    }

    if ($Uninstall) {
        Remove-WebSearch
        return
    }

    # Pre-flight checks
    if (-not $SkipDocker) {
        if (-not (Test-Docker)) { return }
    }

    if (-not (Test-Ollama)) { return }

    # Configure Ollama
    Set-OllamaDockerAccess | Out-Null

    # Download models
    if (-not $SkipModels) {
        Install-WebSearchModels | Out-Null
    }

    # Install based on selection
    if (-not $SkipDocker) {
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
