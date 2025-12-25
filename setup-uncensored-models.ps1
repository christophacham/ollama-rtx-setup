<#
.SYNOPSIS
    Uncensored Models Setup for Ollama
    Optimized for NVIDIA RTX 5090 (32GB VRAM)

.DESCRIPTION
    Downloads uncensored/unfiltered models that fit within 32GB VRAM.
    Assumes Ollama is already installed and running.
    Only downloads models that aren't already installed.

.NOTES
    Models included: dolphin3, dolphin-mistral, wizard-vicuna-uncensored, llama2-uncensored
    All models by Eric Hartford or based on his uncensoring techniques.
#>

param(
    [switch]$ForceDownload,
    [switch]$Help
)

# Colors
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Skip { param($msg) Write-Host "[SKIP] $msg" -ForegroundColor DarkGray }

# Banner
function Show-Banner {
    Write-Host @"

 _   _                                            _
| | | |_ __   ___ ___ _ __  ___  ___  _ __ ___  __| |
| | | | '_ \ / __/ _ \ '_ \/ __|/ _ \| '__/ _ \/ _` |
| |_| | | | | (_|  __/ | | \__ \ (_) | | |  __/ (_| |
 \___/|_| |_|\___\___|_| |_|___/\___/|_|  \___|\__,_|

      Uncensored Models for RTX 5090 (32GB VRAM)
         Models by Eric Hartford & Community

"@ -ForegroundColor Magenta
}

# Help
function Show-Help {
    Write-Host @"
Usage: .\setup-uncensored-models.ps1 [options]

Options:
    -ForceDownload   Re-download models even if already installed
    -Help            Show this help message

Prerequisites:
    - Ollama must be installed (run setup-ollama.ps1 first)
    - Ollama service must be running

Uncensored Models for 32GB VRAM:
    - dolphin3:8b              (~5GB)  - Latest Dolphin, general purpose
    - dolphin-mistral:7b       (~4GB)  - Uncensored coding model
    - wizard-vicuna-uncensored:13b (~8GB) - Classic uncensored assistant
    - llama2-uncensored:7b     (~4GB)  - Original uncensored Llama 2
    - dolphin-phi:2.7b         (~2GB)  - Lightweight uncensored

Total VRAM needed: ~23GB (leaves room for context window)

What is "uncensored"?
    These models have had alignment/safety filters removed or were
    trained without them. They will comply with any request and
    won't refuse based on content. Use responsibly.

Examples:
    .\setup-uncensored-models.ps1              # Install missing models
    .\setup-uncensored-models.ps1 -ForceDownload  # Re-download all
"@
}

# Check if Ollama is installed
function Test-OllamaInstalled {
    $ollama = Get-Command ollama -ErrorAction SilentlyContinue
    return $null -ne $ollama
}

# Check if Ollama service is running
function Test-OllamaRunning {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Get installed models
function Get-InstalledModels {
    $installed = @{}

    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        if ($response.models) {
            foreach ($model in $response.models) {
                $name = $model.name
                $installed[$name] = @{
                    Name = $name
                    Size = $model.size
                    Modified = $model.modified_at
                }
            }
        }
    } catch {
        # Fallback to ollama list
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

# Check if model is installed (with fuzzy matching)
function Test-ModelInstalled {
    param([string]$ModelName, [hashtable]$InstalledModels)

    # Direct match
    if ($InstalledModels.ContainsKey($ModelName)) {
        return $true
    }

    # Try matching base name with any tag
    foreach ($key in $InstalledModels.Keys) {
        $keyBase = ($key -split ":")[0]
        $modelBase = ($ModelName -split ":")[0]
        $keyTag = if ($key -match ":(.+)$") { $matches[1] } else { "latest" }
        $modelTag = if ($ModelName -match ":(.+)$") { $matches[1] } else { "latest" }

        if ($keyBase -eq $modelBase -and $keyTag -eq $modelTag) {
            return $true
        }
        # Also match if just base names match and we're looking for latest
        if ($keyBase -eq $modelBase -and $modelTag -eq "latest" -and $key -eq $keyBase) {
            return $true
        }
    }

    return $false
}

# Main execution
function Main {
    Show-Banner

    if ($Help) {
        Show-Help
        return
    }

    # Check prerequisites
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    Write-Host ""

    # Check Ollama installed
    if (-not (Test-OllamaInstalled)) {
        Write-Err "Ollama is not installed!"
        Write-Host ""
        Write-Host "Please install Ollama first:" -ForegroundColor Yellow
        Write-Host "  1. Run: .\setup-ollama.ps1"
        Write-Host "  2. Or download from: https://ollama.com/download"
        Write-Host ""
        exit 1
    }
    Write-Success "Ollama is installed"

    # Check Ollama running
    if (-not (Test-OllamaRunning)) {
        Write-Err "Ollama service is not running!"
        Write-Host ""
        Write-Host "Please start Ollama:" -ForegroundColor Yellow
        Write-Host "  Run: ollama serve"
        Write-Host "  Or start Ollama from the system tray"
        Write-Host ""
        exit 1
    }
    Write-Success "Ollama service is running"
    Write-Host ""

    # Define uncensored models (optimized for 32GB VRAM)
    $uncensoredModels = @(
        @{
            Name = "dolphin3:8b"
            Desc = "Latest Dolphin - general purpose, agentic, function calling"
            Size = "~5GB"
            Author = "Eric Hartford"
        },
        @{
            Name = "dolphin-mistral:7b"
            Desc = "Uncensored Mistral - excels at coding tasks"
            Size = "~4GB"
            Author = "Eric Hartford"
        },
        @{
            Name = "wizard-vicuna-uncensored:13b"
            Desc = "Classic uncensored assistant based on Llama 2"
            Size = "~8GB"
            Author = "Eric Hartford"
        },
        @{
            Name = "llama2-uncensored:7b"
            Desc = "Original uncensored Llama 2"
            Size = "~4GB"
            Author = "George Sung"
        },
        @{
            Name = "dolphin-phi"
            Desc = "Lightweight uncensored based on Microsoft Phi"
            Size = "~2GB"
            Author = "Eric Hartford"
        }
    )

    Write-Host "Uncensored Models for 32GB VRAM:" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    foreach ($model in $uncensoredModels) {
        Write-Host "  - $($model.Name) $($model.Size)" -ForegroundColor White
        Write-Host "    $($model.Desc)" -ForegroundColor Gray
    }
    Write-Host ""

    # Get installed models
    Write-Info "Checking installed models..."
    $installedModels = Get-InstalledModels

    if ($installedModels.Count -gt 0) {
        Write-Info "Found $($installedModels.Count) installed model(s)"
    }

    # Determine what needs downloading
    $toDownload = @()
    $alreadyInstalled = @()

    foreach ($model in $uncensoredModels) {
        if (-not $ForceDownload -and (Test-ModelInstalled -ModelName $model.Name -InstalledModels $installedModels)) {
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
        Write-Success "All uncensored models are already installed!"
        Write-Host ""
        Write-Host "Usage examples:" -ForegroundColor Yellow
        Write-Host '  ollama run dolphin3 "Write a story about..."'
        Write-Host '  ollama run dolphin-mistral "Help me code..."'
        Write-Host '  ollama run wizard-vicuna-uncensored "Explain..."'
        Write-Host ""
        return
    }

    Write-Host ""
    Write-Host "Models to download:" -ForegroundColor Yellow
    foreach ($model in $toDownload) {
        Write-Host "  - $($model.Name) $($model.Size) - $($model.Desc)"
    }
    Write-Host ""

    # Download models
    $successCount = 0
    $totalToDownload = $toDownload.Count

    foreach ($model in $toDownload) {
        Write-Info "Downloading $($model.Name) ($($successCount + 1)/$totalToDownload)..."
        Write-Host "  Author: $($model.Author) | Size: $($model.Size)" -ForegroundColor Gray

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
        Write-Host ""
    }

    # Summary
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  DOWNLOAD COMPLETE                     " -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Downloaded: $successCount of $totalToDownload models"
    Write-Host "Total uncensored models available: $($alreadyInstalled.Count + $successCount)"
    Write-Host ""
    Write-Host "Usage examples:" -ForegroundColor Yellow
    Write-Host '  ollama run dolphin3 "Your prompt here"'
    Write-Host '  ollama run dolphin-mistral "Help me with code"'
    Write-Host '  ollama run wizard-vicuna-uncensored "Explain something"'
    Write-Host ""
    Write-Warn "Remember: These models have no content filters."
    Write-Warn "Use responsibly and ethically."
    Write-Host ""
}

# Run
Main
