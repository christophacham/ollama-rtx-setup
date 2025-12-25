<#
.SYNOPSIS
    Ollama Setup Script for PAL MCP Server
    Optimized for NVIDIA RTX 5090 (32GB VRAM)

.DESCRIPTION
    This script automates the complete setup of Ollama with PAL MCP Server:
    - Installs Ollama if not present
    - Downloads optimal models for 32GB VRAM
    - Configures .env file for PAL MCP
    - Updates custom_models.json with model definitions
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
    -Help            Show this help message

Examples:
    .\setup-ollama.ps1                    # Full setup with core models
    .\setup-ollama.ps1 -MinimalModels     # Quick setup with one model
    .\setup-ollama.ps1 -AllModels         # Download all 5 recommended models
    .\setup-ollama.ps1 -SkipModels        # Configure only, no downloads

Models for 32GB VRAM:
    Core (default):
      - qwen2.5-coder:32b  (~19GB) - Best coding model
      - deepseek-r1:32b    (~19GB) - Best reasoning model
      - qwen3:32b          (~19GB) - Best general model

    Additional (-AllModels):
      - codellama:34b      (~20GB) - Meta's coding model
      - deepseek-coder:33b (~19GB) - Alternative coder
"@
}

# Check if running as admin (not required but helpful)
function Test-Administrator {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
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

                # Parse VRAM
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

# Install Ollama
function Install-Ollama {
    Write-Step "1" "Installing Ollama"

    if (Test-OllamaInstalled) {
        $version = ollama --version 2>$null
        Write-Success "Ollama is already installed: $version"
        return $true
    }

    Write-Info "Ollama not found. Installing via winget..."

    # Check if winget is available
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
    Write-Step "2" "Starting Ollama Service"

    # Check if already running
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
        Write-Success "Ollama service is already running"
        return $true
    } catch {
        Write-Info "Ollama service not running. Starting..."
    }

    # Start Ollama in background
    try {
        Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
        Start-Sleep -Seconds 3

        # Verify it started
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 10 -ErrorAction Stop
        Write-Success "Ollama service started successfully"
        return $true
    } catch {
        Write-Warn "Could not start Ollama service automatically."
        Write-Info "Please run 'ollama serve' in a separate terminal, then run this script with -SkipInstall"
        return $false
    }
}

# Download models
function Install-Models {
    param([bool]$Minimal, [bool]$All)

    Write-Step "3" "Downloading Models"

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
        $models = @($coreModels[0])  # Just qwen2.5-coder:32b
        Write-Info "Minimal mode: Downloading only qwen2.5-coder:32b"
    } elseif ($All) {
        $models = $coreModels + $extraModels
        Write-Info "Full mode: Downloading all 5 recommended models"
    } else {
        $models = $coreModels
        Write-Info "Standard mode: Downloading 3 core models"
    }

    # Show what we're downloading
    Write-Host "`nModels to download:" -ForegroundColor Yellow
    foreach ($model in $models) {
        Write-Host "  - $($model.Name) $($model.Size) - $($model.Desc)"
    }
    Write-Host ""

    # Download each model
    $successCount = 0
    foreach ($model in $models) {
        Write-Info "Downloading $($model.Name)..."
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

    Write-Success "Downloaded $successCount of $($models.Count) models"
    return $successCount -gt 0
}

# Configure .env file
function Update-EnvFile {
    Write-Step "4" "Configuring .env File"

    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }

    $envFile = Join-Path $scriptDir ".env"
    $envExample = Join-Path $scriptDir ".env.example"

    # Create .env from example if it doesn't exist
    if (-not (Test-Path $envFile)) {
        if (Test-Path $envExample) {
            Copy-Item $envExample $envFile
            Write-Info "Created .env from .env.example"
        } else {
            Write-Warn ".env.example not found. Creating minimal .env"
            "" | Out-File $envFile -Encoding utf8
        }
    }

    # Read current content
    $content = Get-Content $envFile -Raw -ErrorAction SilentlyContinue
    if (-not $content) { $content = "" }

    # Check if Ollama config already exists
    if ($content -match "CUSTOM_API_URL.*localhost:11434") {
        Write-Success "Ollama configuration already present in .env"
        return $true
    }

    # Add Ollama configuration
    $ollamaConfig = @"

# =============================================
# Ollama Local Models Configuration
# Added by setup-ollama.ps1
# =============================================
CUSTOM_API_URL=http://localhost:11434/v1
CUSTOM_API_KEY=
CUSTOM_MODEL_NAME=qwen2.5-coder:32b

"@

    # Append to .env
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

    # New model definitions for 32GB VRAM
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

    # Backup existing config
    if (Test-Path $configPath) {
        $backupPath = "$configPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $configPath $backupPath
        Write-Info "Backed up existing config to $backupPath"
    }

    # Write new config
    $newConfig | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding utf8
    Write-Success "Updated custom_models.json with 32GB VRAM optimized models"
    return $true
}

# Verify setup
function Test-Setup {
    Write-Step "6" "Verifying Setup"

    $allGood = $true

    # Check Ollama
    Write-Info "Checking Ollama installation..."
    if (Test-OllamaInstalled) {
        Write-Success "Ollama is installed"
    } else {
        Write-Err "Ollama is not installed"
        $allGood = $false
    }

    # Check Ollama service
    Write-Info "Checking Ollama service..."
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        Write-Success "Ollama service is running"

        # List installed models
        if ($response.models -and $response.models.Count -gt 0) {
            Write-Success "Installed models:"
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

    # Check .env
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
        Write-Err ".env file not found"
        $allGood = $false
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
        Write-Host "Documentation: docs/OLLAMA_SETUP.md" -ForegroundColor Gray
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

    # Install Ollama
    if (-not $SkipInstall) {
        if (-not (Install-Ollama)) {
            $success = $false
        }
    } else {
        Write-Info "Skipping Ollama installation check"
    }

    # Start service
    if ($success -and -not $SkipInstall) {
        if (-not (Start-OllamaService)) {
            $success = $false
        }
    }

    # Download models
    if ($success -and -not $SkipModels) {
        if (-not (Install-Models -Minimal:$MinimalModels -All:$AllModels)) {
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
