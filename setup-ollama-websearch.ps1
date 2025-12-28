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
    [ValidateSet("OpenWebUI", "Perplexica", "Both", "")]
    [string]$Setup = "",
    [switch]$SkipModels,
    [switch]$SkipContainers,
    [switch]$Uninstall,
    [switch]$UseLocalRegistry,
    [switch]$SingleUser,
    [switch]$Help
)

# Script-level container runtime (docker or podman)
$script:ContainerRuntime = $null
$script:ComposeCommand = $null
$script:ImageRegistry = $null
$script:WebUISecretKey = $null

# Generate or retrieve persistent secret key for Open WebUI
function Get-WebUISecretKey {
    $secretFile = Join-Path $env:USERPROFILE ".ollama-rtx-setup-secret"

    if (Test-Path $secretFile) {
        $key = Get-Content $secretFile -Raw
        if ($key -and $key.Length -ge 32) {
            return $key.Trim()
        }
    }

    # Generate new 48-char hex key
    $key = [guid]::NewGuid().ToString().Replace("-","") + [guid]::NewGuid().ToString().Replace("-","").Substring(0,16)
    Set-Content $secretFile $key -NoNewline
    Write-Info "Generated new WEBUI_SECRET_KEY (saved for persistence)"
    return $key
}

# Get installed Ollama models for pre-selection
function Get-OllamaModels {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        if ($response.models -and $response.models.Count -gt 0) {
            $modelNames = $response.models | ForEach-Object { $_.name }
            return ($modelNames -join ',')
        }
    } catch {}
    return $null
}

# Get image reference (supports local registry mirroring)
function Get-ImageRef {
    param(
        [string]$Name,
        [string]$Tag
    )

    if ($script:ImageRegistry) {
        return "$($script:ImageRegistry)/${Name}:${Tag}"
    }

    # Return upstream defaults
    switch ($Name) {
        "open-webui" { return "ghcr.io/open-webui/open-webui:$Tag" }
        "searxng" { return "docker.io/searxng/searxng:$Tag" }
        "perplexica-backend" { return "docker.io/itzcrazykns1337/perplexica-backend:$Tag" }
        "perplexica-frontend" { return "docker.io/itzcrazykns1337/perplexica-frontend:$Tag" }
        default { return "${Name}:${Tag}" }
    }
}

# Colors for output
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Step { param($step, $msg) Write-Host "`n=== Step $step : $msg ===" -ForegroundColor Magenta }

# Container health checking functions
function Test-ContainerHealth {
    param([string]$Container)

    # Check if container exists
    $exists = & $script:ContainerRuntime ps -a --filter "name=^${Container}$" --format "{{.Names}}" 2>$null
    if (-not $exists) {
        return @{ Healthy = $false; Reason = "Container does not exist" }
    }

    # Check if running
    $status = & $script:ContainerRuntime inspect $Container --format "{{.State.Status}}" 2>$null
    if ($status -ne "running") {
        return @{ Healthy = $false; Reason = "Container not running (status: $status)" }
    }

    # Check restart count (detect restart loops)
    $restarts = & $script:ContainerRuntime inspect $Container --format "{{.RestartCount}}" 2>$null
    if ([int]$restarts -gt 3) {
        return @{ Healthy = $false; Reason = "Restart loop detected ($restarts restarts)" }
    }

    # Check health status if available
    $health = & $script:ContainerRuntime inspect $Container --format "{{.State.Health.Status}}" 2>$null
    if ($health -and $health -ne "" -and $health -ne "healthy" -and $health -ne "<no value>") {
        return @{ Healthy = $false; Reason = "Health check failing ($health)" }
    }

    return @{ Healthy = $true; Health = $health }
}

function Show-ContainerLogs {
    param(
        [string]$Container,
        [int]$Lines = 20
    )
    Write-Host "`n--- Last $Lines lines of $Container logs ---" -ForegroundColor Yellow
    & $script:ContainerRuntime logs --tail $Lines $Container 2>&1
    Write-Host "--- End of logs ---`n" -ForegroundColor Yellow
}

function Wait-ContainerReady {
    param(
        [string]$Container,
        [int]$TimeoutSeconds = 60,
        [int]$CheckIntervalSeconds = 5
    )

    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        $health = Test-ContainerHealth -Container $Container
        if ($health.Healthy) {
            return $true
        }

        # If container is restarting or exited, fail fast
        if ($health.Reason -match "not running|Restart loop") {
            Write-Err "Container $Container failed: $($health.Reason)"
            Show-ContainerLogs -Container $Container
            return $false
        }

        Start-Sleep -Seconds $CheckIntervalSeconds
        $elapsed += $CheckIntervalSeconds
        Write-Host "  Waiting for $Container... ($elapsed/$TimeoutSeconds sec)" -ForegroundColor Gray
    }

    Write-Err "Container $Container failed to become healthy within $TimeoutSeconds seconds"
    Show-ContainerLogs -Container $Container
    return $false
}

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
    -Setup <type>    Choose setup type (prompts interactively if omitted):
                     - OpenWebUI - Beautiful UI with web search
                     - Perplexica - Full privacy with SearXNG
                     - Both - Install both options
    -SingleUser      No login required (recommended for personal use)
    -SkipModels      Skip downloading web search optimized models
    -SkipContainers  Skip container setup (config only)
    -Uninstall       Remove web search containers
    -UseLocalRegistry Use mirrored images from ghcr.io/christophacham
    -Help            Show this help message

Examples:
    .\setup-ollama-websearch.ps1                     # Interactive menu
    .\setup-ollama-websearch.ps1 -Setup OpenWebUI -SingleUser  # Ready-to-use
    .\setup-ollama-websearch.ps1 -Setup OpenWebUI    # Install Open WebUI
    .\setup-ollama-websearch.ps1 -Setup Perplexica   # Install Perplexica
    .\setup-ollama-websearch.ps1 -Setup Both         # Install both
    .\setup-ollama-websearch.ps1 -Uninstall          # Remove containers

Container Runtime:
    Automatically detects Docker or Podman (Docker preferred)

Web Search Options:
    Open WebUI:
      - ChatGPT-like interface
      - Multi-engine search via SearXNG (DuckDuckGo, Google, Brave, etc.)
      - Self-hosted, no rate limits
      - Access: http://localhost:3000 (Open WebUI)
                http://localhost:4000 (SearXNG)

    Perplexica:
      - Perplexity AI alternative
      - 100% private with SearXNG
      - Citations and source references
      - Access: http://localhost:3002 (frontend)
                http://localhost:4000 (SearXNG)
"@
}

# Interactive setup menu
function Show-SetupMenu {
    Write-Host ""
    $title = "Web Search Setup"
    $message = "Which web search interface would you like to install?"

    $options = @(
        [System.Management.Automation.Host.ChoiceDescription]::new(
            "&OpenWebUI", "ChatGPT-like interface with built-in web search (Recommended)")
        [System.Management.Automation.Host.ChoiceDescription]::new(
            "&Perplexica", "Perplexity AI alternative with SearXNG for full privacy")
        [System.Management.Automation.Host.ChoiceDescription]::new(
            "&Both", "Install both Open WebUI and Perplexica")
    )

    $result = $Host.UI.PromptForChoice($title, $message, $options, 0)

    switch ($result) {
        0 { return "OpenWebUI" }
        1 { return "Perplexica" }
        2 { return "Both" }
    }
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
# Optimized for RTX 5090 (32GB VRAM) - leaves ~14GB for context
function Install-WebSearchModels {
    Write-Step "4" "Installing Web Search Optimized Models"

    $models = @(
        @{ Name = "qwen2.5:3b"; Desc = "Fast web search queries"; Size = "~2GB" },
        @{ Name = "qwen2.5:14b"; Desc = "Synthesis and aggregation"; Size = "~8GB" },
        @{ Name = "qwen2.5-coder:14b"; Desc = "Code generation"; Size = "~8GB" }
    )

    Write-Host "`nDownloading models optimized for RTX 5090 (32GB VRAM):" -ForegroundColor Yellow
    Write-Host "  Total VRAM: ~18GB | Remaining for context: ~14GB" -ForegroundColor Gray
    Write-Host ""
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

# Test a single model's inference capability via Ollama API
function Test-ModelInference {
    param(
        [string]$ModelName,
        [string]$Prompt = "Reply with only: OK",
        [int]$TimeoutSec = 60
    )

    try {
        $body = @{
            model = $ModelName
            prompt = $Prompt
            stream = $false
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" `
            -Method Post -Body $body -ContentType "application/json" -TimeoutSec $TimeoutSec -ErrorAction Stop

        return @{
            Success = $true
            Response = $response.response
        }
    } catch {
        return @{
            Success = $false
            Response = $_.Exception.Message
        }
    }
}

# Test SearXNG web search API
function Test-SearXNG {
    param([string]$Query = "test")

    try {
        $url = "http://localhost:4000/search?q=$([Uri]::EscapeDataString($Query))&format=json"
        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop

        if ($response.results -and $response.results.Count -gt 0) {
            return @{
                Success = $true
                ResultCount = $response.results.Count
                FirstResult = $response.results[0].title
            }
        }
        return @{ Success = $false; ResultCount = 0 }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Test all installed web search models with full web search integration
function Test-InstalledModels {
    Write-Step "4b" "Testing Models & Web Search"

    $models = @("qwen2.5:3b", "qwen2.5:14b", "qwen2.5-coder:14b")
    $passed = 0

    Write-Host ""
    Write-Host "Running inference test on each model..." -ForegroundColor Gray
    Write-Host ""

    # Phase 1: Basic inference test
    foreach ($model in $models) {
        Write-Info "Testing $model inference..."
        $result = Test-ModelInference -ModelName $model -Prompt "Reply with only: OK"
        if ($result.Success -and $result.Response -match "OK|ok") {
            Write-Success "$model inference OK"
            $passed++
        } else {
            Write-Warn "$model inference failed: $($result.Response)"
        }
    }

    Write-Host ""
    if ($passed -eq $models.Count) {
        Write-Success "All $passed/$($models.Count) models passed basic inference"
    } else {
        Write-Warn "$passed/$($models.Count) models passed basic inference"
    }

    # Phase 2: Test SearXNG if available
    Write-Host ""
    Write-Info "Checking SearXNG availability..."

    $searxngRunning = $false
    try {
        $null = Invoke-RestMethod -Uri "http://localhost:4000/config" -Method Get -TimeoutSec 3 -ErrorAction Stop
        $searxngRunning = $true
    } catch {}

    if ($searxngRunning) {
        Write-Success "SearXNG is running"

        $searchResult = Test-SearXNG -Query "what is the current date"
        if ($searchResult.Success) {
            Write-Success "SearXNG returned $($searchResult.ResultCount) results"
            Write-Info "First result: $($searchResult.FirstResult)"

            # Phase 3: Test model with web search context
            Write-Host ""
            Write-Info "Testing model with web search context..."

            $webContext = "Based on web search results: $($searchResult.FirstResult). What is this about? Reply briefly."
            $webResult = Test-ModelInference -ModelName $models[0] -Prompt $webContext -TimeoutSec 90

            if ($webResult.Success) {
                Write-Success "$($models[0]) processed web search context"
                Write-Host "  Response: $($webResult.Response.Substring(0, [Math]::Min(100, $webResult.Response.Length)))..." -ForegroundColor Gray
            } else {
                Write-Warn "Web search context test failed"
            }
        } else {
            Write-Warn "SearXNG search returned no results"
        }
    } else {
        Write-Warn "SearXNG not running - this is unexpected"
        Write-Info "SearXNG should have started automatically with Open WebUI"
        Write-Info "Try: .\setup-ollama-websearch.ps1 -Setup OpenWebUI"
    }

    # Phase 4: Check Open WebUI logs if running
    $openWebuiRunning = Invoke-Container @("ps", "--filter", "name=open-webui", "--format", "{{.Names}}") 2>&1
    if ($openWebuiRunning -eq "open-webui") {
        Write-Host ""
        Write-Info "Open WebUI is running - checking recent logs for web search activity..."
        $logs = Invoke-Container @("logs", "--tail", "20", "open-webui") 2>&1 | Out-String

        if ($logs -match "web.*search|searx|duckduckgo|RAG") {
            Write-Success "Web search activity detected in Open WebUI logs"
        } else {
            Write-Info "No recent web search activity in logs (normal if no queries sent)"
        }
    }

    Write-Host ""
    return $passed -eq $models.Count
}

# Ensure SearXNG settings exist
function New-SearXNGConfig {
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }

    $searxngDir = Join-Path $scriptDir "searxng"
    $settingsPath = Join-Path $searxngDir "settings.yml"

    # Only create if doesn't exist
    if (Test-Path $settingsPath) {
        return $true
    }

    New-Item -ItemType Directory -Path $searxngDir -Force | Out-Null

    $secretKey = [guid]::NewGuid().ToString()
    $searxngSettings = @"
use_default_settings: true

server:
  secret_key: "$secretKey"
  bind_address: "0.0.0.0"

search:
  safe_search: 0
  autocomplete: "duckduckgo"
  default_lang: "en"
  formats:
    - html
    - json

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
    [System.IO.File]::WriteAllText($settingsPath, $searxngSettings)
    Write-Success "Created searxng/settings.yml"
    return $true
}

# Start SearXNG container (always used with Open WebUI)
function Start-SearXNG {
    Write-Info "Ensuring SearXNG is running..."

    # Check if already running
    $running = Invoke-Container @("ps", "--filter", "name=searxng", "--format", "{{.Names}}") 2>&1
    if ($running -eq "searxng") {
        Write-Success "SearXNG already running"
        return $true
    }

    # Check if exists but stopped
    $exists = Invoke-Container @("ps", "-a", "--filter", "name=searxng", "--format", "{{.Names}}") 2>&1
    if ($exists -eq "searxng") {
        Write-Info "Starting existing SearXNG container..."
        Invoke-Container @("start", "searxng") | Out-Null
        Start-Sleep -Seconds 3
        Write-Success "SearXNG started"
        return $true
    }

    # Create config if needed
    New-SearXNGConfig | Out-Null

    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }

    $searxngImage = Get-ImageRef -Name "searxng" -Tag "latest"
    Write-Info "Pulling SearXNG image..."

    # Run SearXNG container
    $containerArgs = @(
        "run", "-d",
        "-p", "4000:8080",
        "-v", "${scriptDir}/searxng:/etc/searxng",
        "-e", "SEARXNG_BASE_URL=http://localhost:4000",
        "--name", "searxng",
        "--restart", "unless-stopped",
        $searxngImage
    )

    try {
        $result = Invoke-Container $containerArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to start SearXNG: $result"
            return $false
        }

        # Wait for SearXNG to be ready
        Write-Info "Waiting for SearXNG to start..."
        $attempts = 0
        while ($attempts -lt 10) {
            Start-Sleep -Seconds 2
            try {
                $null = Invoke-RestMethod -Uri "http://localhost:4000/config" -Method Get -TimeoutSec 3 -ErrorAction Stop
                Write-Success "SearXNG is running at http://localhost:4000"
                return $true
            } catch {
                $attempts++
            }
        }
        Write-Warn "SearXNG started but not responding yet"
        return $true
    } catch {
        Write-Err "SearXNG error: $_"
        return $false
    }
}

# Install Open WebUI
function Install-OpenWebUI {
    Write-Step "5" "Installing Open WebUI + SearXNG"

    # Always start SearXNG first
    if (-not (Start-SearXNG)) {
        Write-Warn "SearXNG failed to start, continuing anyway..."
    }

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
    $desiredImage = Get-ImageRef -Name "open-webui" -Tag $desiredTag

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

    # SearXNG is always started with Open WebUI (no fallback to external providers)
    # SearXNG URL uses the same host as Ollama but different port
    $searxngUrl = $ollamaUrl -replace ':11434', ':4000'
    Write-Info "Using SearXNG at $searxngUrl for web search"

    $webSearchArgs = @(
        "-e", "ENABLE_RAG_WEB_SEARCH=true",
        "-e", "RAG_WEB_SEARCH_ENGINE=searxng",
        "-e", "SEARXNG_QUERY_URL=$searxngUrl",
        "-e", "RAG_WEB_SEARCH_RESULT_COUNT=5"
    )

    # Get persistent secret key for session management
    $secretKey = Get-WebUISecretKey
    Write-Info "Using persistent WEBUI_SECRET_KEY"

    # Get installed models for pre-selection
    $defaultModels = Get-OllamaModels
    if ($defaultModels) {
        Write-Info "Pre-selecting models: $defaultModels"
    }

    # Build container run command
    # :cuda tag = CUDA support + connects to external Ollama (no embedded Ollama)
    # :main tag = CPU only + connects to external Ollama
    $containerArgs = @(
        "run", "-d",
        "-p", "3000:8080",
        "-v", "open-webui:/app/backend/data",
        "-e", "OLLAMA_BASE_URL=$ollamaUrl",
        "-e", "WEBUI_SECRET_KEY=$secretKey"
    ) + $webSearchArgs

    # Add single-user mode (no authentication)
    if ($SingleUser) {
        $containerArgs += @("-e", "WEBUI_AUTH=False")
        Write-Info "Single-user mode enabled (no login required)"
    }

    # Add default models if available
    if ($defaultModels) {
        $containerArgs += @("-e", "DEFAULT_MODELS=$defaultModels")
    }

    $containerArgs += @(
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
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to start Open WebUI: $result"
            return $false
        }

        # Wait for container to become healthy
        Write-Info "Waiting for Open WebUI to start..."
        if (-not (Wait-ContainerReady -Container "open-webui" -TimeoutSeconds 60)) {
            Write-Err "Open WebUI failed to start properly"
            Write-Host ""
            Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
            Write-Host "  1. Check if Ollama is running: ollama ps"
            Write-Host "  2. Check container logs above for errors"
            Write-Host "  3. Try: .\debug-ollama-connection.ps1 -Fix"
            Write-Host ""
            return $false
        }

        Write-Success "Open WebUI installed successfully!"
        Write-Host ""
        Write-Host "  Access Open WebUI at: " -NoNewline
        Write-Host "http://localhost:3000" -ForegroundColor Green
        Write-Host "  Image: $desiredImage (no embedded Ollama)" -ForegroundColor Gray
        Write-Host ""
        if ($SingleUser) {
            Write-Host "  Ready to use:" -ForegroundColor Yellow
            Write-Host "  - No login required (single-user mode)"
            Write-Host "  - Web search pre-enabled with SearXNG"
            if ($defaultModels) {
                Write-Host "  - Models pre-selected: $defaultModels"
            }
        } else {
            Write-Host "  First-time setup:" -ForegroundColor Yellow
            Write-Host "  1. Open http://localhost:3000"
            Write-Host "  2. Create an account (first user becomes admin)"
            Write-Host "  3. Web search is pre-enabled with SearXNG"
        }
        Write-Host ""
        return $true
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

    # Get image references (supports local registry)
    $searxngImage = Get-ImageRef -Name "searxng" -Tag "latest"
    $backendImage = Get-ImageRef -Name "perplexica-backend" -Tag "main"
    $frontendImage = Get-ImageRef -Name "perplexica-frontend" -Tag "main"

    $composeContent = @"
services:
  searxng:
    image: $searxngImage
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
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3

  perplexica-backend:
    image: $backendImage
    container_name: perplexica-backend
    ports:
      - "3001:3001"
    volumes:
      # Note: Perplexica image uses /home/perplexica/ for config
      - ./perplexica/config.toml:/home/perplexica/config.toml
      - ./perplexica/data:/home/perplexica/data
    depends_on:
      searxng:
        condition: service_healthy
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
    networks:
      - perplexica-network
    healthcheck:
      # Using node TCP check since wget/curl not installed in this image
      test: ["CMD", "node", "-e", "require('net').connect(3001,'localhost',()=>process.exit(0)).on('error',()=>process.exit(1))"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  perplexica-frontend:
    image: $frontendImage
    container_name: perplexica-frontend
    ports:
      - "3002:3000"
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:3001
      - NEXT_PUBLIC_WS_URL=ws://localhost:3001
    depends_on:
      perplexica-backend:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - perplexica-network
    healthcheck:
      # Using node TCP check since wget/curl not installed in this image
      test: ["CMD", "node", "-e", "require('net').connect(3000,'localhost',()=>process.exit(0)).on('error',()=>process.exit(1))"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  perplexica-network:
    driver: bridge
"@

    # Use WriteAllText to avoid BOM
    [System.IO.File]::WriteAllText($composePath, $composeContent)
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

    # Get the correct Ollama URL for the detected container runtime
    $ollamaUrl = Get-OllamaHostUrl
    Write-Info "Configuring Perplexica to use Ollama at: $ollamaUrl"

    $configPath = Join-Path $perplexicaDir "config.toml"
    $configContent = @"
[GENERAL]
PORT = 3001
SIMILARITY_MEASURE = "cosine"
KEEP_ALIVE = "5m"

[MODELS.OPENAI]
API_KEY = ""

[MODELS.GROQ]
API_KEY = ""

[MODELS.ANTHROPIC]
API_KEY = ""

[MODELS.GEMINI]
API_KEY = ""

[MODELS.OLLAMA]
API_URL = "$ollamaUrl"

[MODELS.CUSTOM_OPENAI]
API_URL = ""
API_KEY = ""
MODEL_NAME = ""

[API_ENDPOINTS]
SEARXNG = "http://searxng:8080"
"@
    # Use WriteAllText to avoid BOM (TOML parser can't handle BOM)
    [System.IO.File]::WriteAllText($configPath, $configContent)
    Write-Success "Created perplexica/config.toml"

    $searxngSettingsPath = Join-Path $searxngDir "settings.yml"
    $secretKey = [guid]::NewGuid().ToString()
    $searxngSettings = @"
use_default_settings: true

server:
  secret_key: "$secretKey"
  bind_address: "0.0.0.0"

search:
  safe_search: 0
  autocomplete: "duckduckgo"
  default_lang: "en"
  formats:
    - html
    - json

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
    # Use WriteAllText to avoid BOM
    [System.IO.File]::WriteAllText($searxngSettingsPath, $searxngSettings)
    Write-Success "Created searxng/settings.yml"

    return $true
}

# Install Perplexica
function Install-Perplexica {
    Write-Step "5" "Installing Perplexica + SearXNG"

    $existing = Invoke-Container @("ps", "--filter", "name=perplexica", "--format", "{{.Names}}") 2>&1
    if ($existing) {
        # Check health of existing containers
        $allHealthy = $true
        foreach ($container in @("searxng", "perplexica-backend", "perplexica-frontend")) {
            $health = Test-ContainerHealth -Container $container
            if (-not $health.Healthy) {
                Write-Warn "$container issue: $($health.Reason)"
                Show-ContainerLogs -Container $container -Lines 15
                $allHealthy = $false
            }
        }
        if ($allHealthy) {
            Write-Success "Perplexica is already running and healthy"
            Write-Host "  Frontend: http://localhost:3002"
            Write-Host "  SearXNG:  http://localhost:4000"
            return $true
        } else {
            Write-Warn "Some Perplexica containers have issues. Consider restarting with:"
            Write-Host "  .\setup-ollama-websearch.ps1 -Uninstall; .\setup-ollama-websearch.ps1 -Setup Perplexica"
            return $false
        }
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

        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to start Perplexica: $result"
            return $false
        }

        # Wait for containers to become healthy
        Write-Info "Waiting for containers to become healthy..."

        $containers = @(
            @{ Name = "searxng"; Timeout = 60 },
            @{ Name = "perplexica-backend"; Timeout = 90 },
            @{ Name = "perplexica-frontend"; Timeout = 60 }
        )

        $allStarted = $true
        foreach ($c in $containers) {
            Write-Info "Checking $($c.Name)..."
            if (-not (Wait-ContainerReady -Container $c.Name -TimeoutSeconds $c.Timeout)) {
                $allStarted = $false
                # Don't return yet - check all containers to show all issues
            }
        }

        if (-not $allStarted) {
            Write-Err "Some Perplexica containers failed to start properly"
            Write-Host ""
            Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
            Write-Host "  1. Check if Ollama is running: ollama ps"
            Write-Host "  2. Check container logs above for errors"
            Write-Host "  3. If using Podman, verify gateway IP is correct"
            Write-Host "  4. Try: .\debug-ollama-connection.ps1 -Container perplexica-backend"
            Write-Host ""
            return $false
        }

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
            Write-Host "SearXNG:    " -NoNewline
            Write-Host "http://localhost:4000" -ForegroundColor Cyan
            Write-Host ""
            if ($SingleUser) {
                Write-Host "Ready to use! (single-user mode)" -ForegroundColor Green
                Write-Host "  - No login required"
                Write-Host "  - Web search via SearXNG (multi-engine)"
            } else {
                Write-Host "Quick Start:" -ForegroundColor Yellow
                Write-Host "  1. Open http://localhost:3000"
                Write-Host "  2. Create account (first user = admin)"
                Write-Host "  3. Web search via SearXNG (multi-engine)"
            }
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
    Write-Host "Installed Models (RTX 5090 optimized, ~18GB total):" -ForegroundColor Yellow
    Write-Host "  - qwen2.5:3b       (fast web search queries)"
    Write-Host "  - qwen2.5:14b      (synthesis/aggregation)"
    Write-Host "  - qwen2.5-coder:14b (code generation)"
    Write-Host ""
    Write-Host "VRAM Budget: ~18GB used | ~14GB for context" -ForegroundColor Gray
    Write-Host ""
}

# Main
function Main {
    Show-Banner

    if ($Help) {
        Show-Help
        return
    }

    # If -Setup not provided, prompt interactively
    if (-not $Setup) {
        if ([Environment]::UserInteractive -and $Host.Name -ne 'ServerRemoteHost') {
            $script:SelectedSetup = Show-SetupMenu
            Write-Info "Selected: $($script:SelectedSetup)"
        } else {
            # Non-interactive: default to OpenWebUI
            $script:SelectedSetup = "OpenWebUI"
            Write-Info "Non-interactive mode: defaulting to OpenWebUI"
        }
    } else {
        $script:SelectedSetup = $Setup
    }

    # Set image registry if using local mirror
    if ($UseLocalRegistry) {
        $script:ImageRegistry = "ghcr.io/christophacham/ollama-rtx-setup"
        Write-Info "Using local registry: $($script:ImageRegistry)"
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
        Test-InstalledModels | Out-Null
    }

    if (-not $SkipContainers) {
        switch ($script:SelectedSetup) {
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

    Show-Complete -SetupType $script:SelectedSetup
}

# Run
Main
