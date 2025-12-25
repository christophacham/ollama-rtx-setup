<#
.SYNOPSIS
    Ollama Setup Script for PAL MCP Server
    Optimized for NVIDIA RTX 5090 (32GB VRAM)

.DESCRIPTION
    Smart setup script that:
    - Only installs Ollama if not already present
    - Only downloads models that aren't already installed
    - Configures .env file for PAL MCP
    - Verifies everything works correctly

.NOTES
    Target Hardware: NVIDIA RTX 5090 (32GB GDDR7)
    Recommended Models: qwen3:32b, deepseek-r1:32b, qwen2.5-coder:32b
#>

param(
    [switch]$SkipInstall,
    [switch]$SkipModels,
    [switch]$MinimalModels,
    [switch]$AllModels,
    [switch]$ForceDownload,
    [switch]$Help
)

# Colors for output
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Step { param($step, $msg) Write-Host "`n=== Step $step : $msg ===" -ForegroundColor Magenta }
function Write-Skip { param($msg) Write-Host "[SKIP] $msg" -ForegroundColor DarkGray }

# Banner
function Show-Banner {
    Write-Host @"

    ____  ___    __       __  ______________     ____  ____
   / __ \/   |  / /      /  |/  / ____/ __ \   / __ \/ __ \
  / /_/ / /| | / /      / /|_/ / /   / /_/ /  / /_/ / / / /
 / ____/ ___ |/ /___   / /  / / /___/ ____/  / ____/ /_/ /
/_/   /_/  |_/_____/  /_/  /_/\____/_/      /_/    \____/

           Ollama Setup for RTX 5090 (32GB VRAM)

"@ -ForegroundColor Cyan
}

# Help
function Show-Help {
    Write-Host @"
Usage: .\setup-ollama.ps1 [options]

Options:
    -SkipInstall     Skip Ollama installation check
    -SkipModels      Skip model downloads
    -MinimalModels   Download only essential models (qwen2.5-coder:32b)
    -AllModels       Download all recommended models for 32GB VRAM
    -ForceDownload   Re-download models even if already installed
    -Help            Show this help message

Examples:
    .\setup-ollama.ps1                    # Smart setup (skips existing)
    .\setup-ollama.ps1 -MinimalModels     # Quick setup with one model
    .\setup-ollama.ps1 -AllModels         # Download all 5 recommended models
    .\setup-ollama.ps1 -ForceDownload     # Re-download all models
    .\setup-ollama.ps1 -SkipModels        # Configure only, no downloads

Models for 32GB VRAM:
    Core (default):
      - qwen2.5-coder:32b  (~19GB) - Best coding model
      - deepseek-r1:32b    (~19GB) - Best reasoning model
      - qwen3:32b          (~19GB) - Best general model

    Additional (-AllModels):
      - codellama:34b      (~20GB) - Meta's coding model
      - deepseek-coder:33b (~19GB) - Alternative coder

Smart Features:
    - Only installs Ollama if not already present
    - Only downloads models that aren't already installed
    - Shows which models are skipped vs downloaded
"@
}

# Check NVIDIA GPU
function Get-GPUInfo {
    Write-Step "0" "Detecting GPU"

    try {
        $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
        if ($nvidiaSmi) {
            $gpuInfo = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
            if ($gpuInfo) {
                Write-Success "NVIDIA GPU detected: $gpuInfo"

                if ($gpuInfo -match "(\d+)\s*MiB") {
                    $vramMB = [int]$matches[1]
                    $vramGB = [math]::Round($vramMB / 1024, 1)
                    Write-Info "Available VRAM: ${vramGB}GB"

                    if ($vramGB -ge 32) {
                        Write-Success "32GB+ VRAM detected - All 32B models supported!"
                    } elseif ($vramGB -ge 24) {
                        Write-Warn "24GB VRAM - 32B models will work with Q4 quantization"
                    } elseif ($vramGB -ge 16) {
                        Write-Warn "16GB VRAM - Consider using 14B or smaller models"
                    } else {
                        Write-Warn "Limited VRAM - 8B models recommended"
                    }
                    return $vramGB
                }
            }
        }
    } catch {
        Write-Warn "Could not detect NVIDIA GPU. Proceeding anyway..."
    }
    return 0
}

# Check if Ollama is installed
function Test-OllamaInstalled {
    $ollama = Get-Command ollama -ErrorAction SilentlyContinue
    return $null -ne $ollama
}

# Get installed models from Ollama
function Get-InstalledModels {
    $installed = @{}

    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        if ($response.models) {
            foreach ($model in $response.models) {
                # Store by name (normalize the name)
                $name = $model.name
                $installed[$name] = @{
                    Name = $name
                    Size = $model.size
                    Modified = $model.modified_at
                }
            }
        }
    } catch {
        # Try using ollama list command as fallback
        try {
            $listOutput = ollama list 2>&1
            if ($LASTEXITCODE -eq 0) {
                $lines = $listOutput -split "`n" | Select-Object -Skip 1
                foreach ($line in $lines) {
                    if ($line -match "^(\S+)") {
                        $name = $matches[1]
                        $installed[$name] = @{ Name = $name; Size = 0; Modified = $null }
                    }
                }
            }
        } catch {}
    }

    return $installed
}

# Check if a specific model is installed
function Test-ModelInstalled {
    param([string]$ModelName, [hashtable]$InstalledModels)

    # Direct match
    if ($InstalledModels.ContainsKey($ModelName)) {
        return $true
    }

    # Try without tag (e.g., "qwen3:32b" matches "qwen3:32b")
    foreach ($key in $InstalledModels.Keys) {
        if ($key -eq $ModelName -or $key.StartsWith("$ModelName:") -or $ModelName.StartsWith("$key:")) {
            return $true
        }
        # Also check if base names match
        $keyBase = ($key -split ":")[0]
        $modelBase = ($ModelName -split ":")[0]
        $keyTag = if ($key -match ":(.+)$") { $matches[1] } else { "latest" }
        $modelTag = if ($ModelName -match ":(.+)$") { $matches[1] } else { "latest" }

        if ($keyBase -eq $modelBase -and $keyTag -eq $modelTag) {
            return $true
        }
    }

    return $false
}

# Install Ollama
function Install-Ollama {
    Write-Step "1" "Checking Ollama Installation"

    if (Test-OllamaInstalled) {
        $version = ollama --version 2>$null
        Write-Skip "Ollama already installed: $version"
        return $true
    }

    Write-Info "Ollama not found. Installing via winget..."

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Err "winget not found. Please install Ollama manually from https://ollama.com/download"
        Write-Info "After installing, run this script again with -SkipInstall"
        return $false
    }

    try {
        winget install Ollama.Ollama --accept-source-agreements --accept-package-agreements

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        if (Test-OllamaInstalled) {
            Write-Success "Ollama installed successfully!"
            return $true
        } else {
            Write-Warn "Ollama installed but not in PATH. You may need to restart your terminal."
            return $true
        }
    } catch {
        Write-Err "Failed to install Ollama: $_"
        return $false
    }
}

# Start Ollama service
function Start-OllamaService {
    Write-Step "2" "Checking Ollama Service"

    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
        Write-Skip "Ollama service already running"
        return $true
    } catch {
        Write-Info "Ollama service not running. Starting..."
    }

    try {
        Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
        Start-Sleep -Seconds 3

        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 10 -ErrorAction Stop
        Write-Success "Ollama service started successfully"
        return $true
    } catch {
        Write-Warn "Could not start Ollama service automatically."
        Write-Info "Please run 'ollama serve' in a separate terminal, then run this script with -SkipInstall"
        return $false
    }
}

# Download models (smart - only missing ones)
function Install-Models {
    param([bool]$Minimal, [bool]$All, [bool]$Force)

    Write-Step "3" "Checking Models"

    # Define models
    $coreModels = @(
        @{ Name = "qwen2.5-coder:32b"; Desc = "Best coding model (92 languages)"; Size = "~19GB" },
        @{ Name = "deepseek-r1:32b"; Desc = "Best reasoning model"; Size = "~19GB" },
        @{ Name = "qwen3:32b"; Desc = "Latest general-purpose model"; Size = "~19GB" }
    )

    $extraModels = @(
        @{ Name = "codellama:34b"; Desc = "Meta's premier coding model"; Size = "~20GB" },
        @{ Name = "deepseek-coder:33b"; Desc = "Strong coding alternative"; Size = "~19GB" }
    )

    # Select models based on flags
    if ($Minimal) {
        $targetModels = @($coreModels[0])
        Write-Info "Minimal mode: Targeting qwen2.5-coder:32b only"
    } elseif ($All) {
        $targetModels = $coreModels + $extraModels
        Write-Info "Full mode: Targeting all 5 recommended models"
    } else {
        $targetModels = $coreModels
        Write-Info "Standard mode: Targeting 3 core models"
    }

    # Get currently installed models
    Write-Info "Checking installed models..."
    $installedModels = Get-InstalledModels

    if ($installedModels.Count -gt 0) {
        Write-Info "Found $($installedModels.Count) installed model(s)"
    }

    # Determine which models need downloading
    $toDownload = @()
    $alreadyInstalled = @()

    foreach ($model in $targetModels) {
        if (-not $Force -and (Test-ModelInstalled -ModelName $model.Name -InstalledModels $installedModels)) {
            $alreadyInstalled += $model
        } else {
            $toDownload += $model
        }
    }

    # Show status
    Write-Host ""
    if ($alreadyInstalled.Count -gt 0) {
        Write-Host "Already installed (skipping):" -ForegroundColor Green
        foreach ($model in $alreadyInstalled) {
            Write-Host "  [OK] $($model.Name)" -ForegroundColor Green
        }
    }

    if ($toDownload.Count -eq 0) {
        Write-Host ""
        Write-Success "All target models are already installed!"
        return $true
    }

    Write-Host ""
    Write-Host "Models to download:" -ForegroundColor Yellow
    foreach ($model in $toDownload) {
        Write-Host "  - $($model.Name) $($model.Size) - $($model.Desc)"
    }
    Write-Host ""

    # Download missing models
    $successCount = 0
    $totalToDownload = $toDownload.Count

    foreach ($model in $toDownload) {
        Write-Info "Downloading $($model.Name) ($($successCount + 1)/$totalToDownload)..."
        Write-Host "  This may take 15-25 minutes depending on your connection speed" -ForegroundColor Gray

        try {
            $process = Start-Process -FilePath "ollama" -ArgumentList "pull $($model.Name)" -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                Write-Success "$($model.Name) downloaded successfully"
                $successCount++
            } else {
                Write-Err "Failed to download $($model.Name)"
            }
        } catch {
            Write-Err "Error downloading $($model.Name): $_"
        }
    }

    Write-Host ""
    Write-Success "Downloaded $successCount of $totalToDownload models"
    Write-Info "Total models now available: $($alreadyInstalled.Count + $successCount)"

    return $successCount -gt 0 -or $alreadyInstalled.Count -gt 0
}

# Configure .env file
function Update-EnvFile {
    Write-Step "4" "Configuring .env File"

    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }

    $envFile = Join-Path $scriptDir ".env"
    $envExample = Join-Path $scriptDir ".env.example"

    if (-not (Test-Path $envFile)) {
        if (Test-Path $envExample) {
            Copy-Item $envExample $envFile
            Write-Info "Created .env from .env.example"
        } else {
            Write-Warn ".env.example not found. Creating minimal .env"
            "" | Out-File $envFile -Encoding utf8
        }
    }

    $content = Get-Content $envFile -Raw -ErrorAction SilentlyContinue
    if (-not $content) { $content = "" }

    if ($content -match "CUSTOM_API_URL.*localhost:11434") {
        Write-Skip "Ollama configuration already present in .env"
        return $true
    }

    $ollamaConfig = @"

# =============================================
# Ollama Local Models Configuration
# Added by setup-ollama.ps1
# =============================================
CUSTOM_API_URL=http://localhost:11434/v1
CUSTOM_API_KEY=
CUSTOM_MODEL_NAME=qwen2.5-coder:32b

"@

    Add-Content -Path $envFile -Value $ollamaConfig
    Write-Success "Added Ollama configuration to .env"
    return $true
}

# Update custom_models.json
function Update-CustomModels {
    Write-Step "5" "Updating custom_models.json"

    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }

    $configPath = Join-Path $scriptDir "conf\custom_models.json"

    # Check if conf directory exists, if not use current directory
    $confDir = Join-Path $scriptDir "conf"
    if (-not (Test-Path $confDir)) {
        $configPath = Join-Path $scriptDir "custom_models.json"
    }

    $newConfig = @{
        "_README" = @{
            "description" = "Model metadata for local/self-hosted OpenAI-compatible endpoints (Custom provider)."
            "documentation" = "https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/custom_models.md"
            "usage" = "Each entry will be advertised by the Custom provider. Aliases are case-insensitive."
            "field_notes" = "Matches providers/shared/model_capabilities.py."
            "updated_by" = "setup-ollama.ps1 - Optimized for RTX 5090 (32GB VRAM)"
        }
        "models" = @(
            @{
                "model_name" = "qwen2.5-coder:32b"
                "aliases" = @("qwen-coder", "qwen-code", "coder", "qwen25-coder")
                "context_window" = 131072
                "max_output_tokens" = 32768
                "supports_extended_thinking" = $false
                "supports_json_mode" = $true
                "supports_function_calling" = $false
                "supports_images" = $false
                "max_image_size_mb" = 0.0
                "description" = "Qwen 2.5 Coder 32B - Best local coding model, 92 languages, matches GitHub Copilot"
                "intelligence_score" = 18
            },
            @{
                "model_name" = "deepseek-r1:32b"
                "aliases" = @("deepseek-r1", "deepseek", "r1", "reasoning")
                "context_window" = 131072
                "max_output_tokens" = 32768
                "supports_extended_thinking" = $true
                "supports_json_mode" = $true
                "supports_function_calling" = $false
                "supports_images" = $false
                "max_image_size_mb" = 0.0
                "description" = "DeepSeek-R1 32B - Best local reasoning model with chain-of-thought"
                "intelligence_score" = 17
            },
            @{
                "model_name" = "qwen3:32b"
                "aliases" = @("qwen3", "qwen", "local-qwen")
                "context_window" = 131072
                "max_output_tokens" = 32768
                "supports_extended_thinking" = $true
                "supports_json_mode" = $true
                "supports_function_calling" = $false
                "supports_images" = $false
                "max_image_size_mb" = 0.0
                "description" = "Qwen3 32B - Latest generation general-purpose model with enhanced reasoning"
                "intelligence_score" = 17
            },
            @{
                "model_name" = "codellama:34b"
                "aliases" = @("codellama", "code-llama", "llama-code")
                "context_window" = 16384
                "max_output_tokens" = 8192
                "supports_extended_thinking" = $false
                "supports_json_mode" = $false
                "supports_function_calling" = $false
                "supports_images" = $false
                "max_image_size_mb" = 0.0
                "description" = "CodeLlama 34B - Meta's premier coding model, production-ready code"
                "intelligence_score" = 15
            },
            @{
                "model_name" = "deepseek-coder:33b"
                "aliases" = @("deepseek-coder", "ds-coder")
                "context_window" = 16384
                "max_output_tokens" = 8192
                "supports_extended_thinking" = $false
                "supports_json_mode" = $true
                "supports_function_calling" = $false
                "supports_images" = $false
                "max_image_size_mb" = 0.0
                "description" = "DeepSeek Coder 33B - Strong coding model with 80+ languages"
                "intelligence_score" = 15
            },
            @{
                "model_name" = "llama3.1:8b"
                "aliases" = @("llama3.1", "llama-8b", "fast-search")
                "context_window" = 131072
                "max_output_tokens" = 32768
                "supports_extended_thinking" = $false
                "supports_json_mode" = $true
                "supports_function_calling" = $true
                "supports_images" = $false
                "max_image_size_mb" = 0.0
                "description" = "Llama 3.1 8B - Fast model for web search, tool calling enabled"
                "intelligence_score" = 12
            },
            @{
                "model_name" = "mistral:7b"
                "aliases" = @("mistral", "mistral-7b", "quick")
                "context_window" = 32768
                "max_output_tokens" = 8192
                "supports_extended_thinking" = $false
                "supports_json_mode" = $true
                "supports_function_calling" = $true
                "supports_images" = $false
                "max_image_size_mb" = 0.0
                "description" = "Mistral 7B - Efficient model for quick queries"
                "intelligence_score" = 10
            },
            @{
                "model_name" = "llama3.2"
                "aliases" = @("local-llama", "ollama-llama", "llama")
                "context_window" = 128000
                "max_output_tokens" = 64000
                "supports_extended_thinking" = $false
                "supports_json_mode" = $false
                "supports_function_calling" = $false
                "supports_images" = $false
                "max_image_size_mb" = 0.0
                "description" = "Llama 3.2 - Lightweight general-purpose model (fallback)"
                "intelligence_score" = 6
            }
        )
    }

    if (Test-Path $configPath) {
        $backupPath = "$configPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $configPath $backupPath
        Write-Info "Backed up existing config to $backupPath"
    }

    $newConfig | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding utf8
    Write-Success "Updated custom_models.json with 32GB VRAM optimized models"
    return $true
}

# Verify setup
function Test-Setup {
    Write-Step "6" "Verifying Setup"

    $allGood = $true

    Write-Info "Checking Ollama installation..."
    if (Test-OllamaInstalled) {
        Write-Success "Ollama is installed"
    } else {
        Write-Err "Ollama is not installed"
        $allGood = $false
    }

    Write-Info "Checking Ollama service..."
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        Write-Success "Ollama service is running"

        if ($response.models -and $response.models.Count -gt 0) {
            Write-Success "Installed models: $($response.models.Count)"
            foreach ($model in $response.models) {
                $sizeGB = [math]::Round($model.size / 1GB, 1)
                Write-Host "    - $($model.name) (${sizeGB}GB)" -ForegroundColor Gray
            }
        } else {
            Write-Warn "No models installed yet"
        }
    } catch {
        Write-Err "Ollama service is not running"
        $allGood = $false
    }

    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }
    $envFile = Join-Path $scriptDir ".env"

    Write-Info "Checking .env configuration..."
    if (Test-Path $envFile) {
        $content = Get-Content $envFile -Raw
        if ($content -match "CUSTOM_API_URL.*localhost:11434") {
            Write-Success ".env is configured for Ollama"
        } else {
            Write-Warn ".env exists but Ollama config may be missing"
        }
    } else {
        Write-Warn ".env file not found (optional)"
    }

    return $allGood
}

# Show completion message
function Show-Complete {
    param([bool]$success)

    Write-Host ""
    if ($success) {
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  SETUP COMPLETE!                       " -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Restart your Claude Code / AI assistant"
        Write-Host "  2. Use local models via PAL:"
        Write-Host ""
        Write-Host '     "Use qwen-coder to review this code"' -ForegroundColor Cyan
        Write-Host '     "Use deepseek-r1 to debug this function"' -ForegroundColor Cyan
        Write-Host '     "Use qwen3 for general analysis"' -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "  SETUP INCOMPLETE                      " -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Some steps failed. Please check the errors above."
        Write-Host "You may need to:"
        Write-Host "  - Install Ollama manually from https://ollama.com/download"
        Write-Host "  - Run 'ollama serve' in a separate terminal"
        Write-Host "  - Run this script again with -SkipInstall"
    }
    Write-Host ""
}

# Main execution
function Main {
    Show-Banner

    if ($Help) {
        Show-Help
        return
    }

    $success = $true

    # Detect GPU
    $vram = Get-GPUInfo

    # Install Ollama (only if needed)
    if (-not $SkipInstall) {
        if (-not (Install-Ollama)) {
            $success = $false
        }
    } else {
        Write-Info "Skipping Ollama installation check"
    }

    # Start service (only if needed)
    if ($success -and -not $SkipInstall) {
        if (-not (Start-OllamaService)) {
            $success = $false
        }
    }

    # Download models (only missing ones)
    if ($success -and -not $SkipModels) {
        if (-not (Install-Models -Minimal:$MinimalModels -All:$AllModels -Force:$ForceDownload)) {
            Write-Warn "Some models failed to download, but continuing..."
        }
    } else {
        Write-Info "Skipping model downloads"
    }

    # Configure .env
    if ($success) {
        Update-EnvFile | Out-Null
    }

    # Update custom_models.json
    if ($success) {
        Update-CustomModels | Out-Null
    }

    # Verify
    $verified = Test-Setup

    # Show completion
    Show-Complete -success:$verified
}

# Run main
Main
