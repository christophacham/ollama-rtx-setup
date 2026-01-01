<#
.SYNOPSIS
    Moves Ollama models to a new location and reconfigures Ollama to use it.

.DESCRIPTION
    This script:
    1. Stops Ollama (service and any running processes)
    2. Creates the target folder if it doesn't exist
    3. Moves all models from the default location to the new location
    4. Sets OLLAMA_MODELS environment variable (system-wide)
    5. Restarts Ollama

.PARAMETER TargetPath
    The new location for Ollama models. Default: X:\OllamaModels

.PARAMETER SkipMove
    If set, only reconfigures the environment variable without moving files.
    Useful if you've already manually moved the files.

.EXAMPLE
    .\move-ollama-models.ps1
    Moves models to X:\OllamaModels

.EXAMPLE
    .\move-ollama-models.ps1 -TargetPath "D:\AI\Models"
    Moves models to D:\AI\Models

.EXAMPLE
    .\move-ollama-models.ps1 -SkipMove
    Only sets OLLAMA_MODELS without moving files
#>

param(
    [string]$TargetPath = "X:\OllamaModels",
    [switch]$SkipMove
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Status($msg) { Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-Success($msg) { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warning($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Error($msg) { Write-Host "[-] $msg" -ForegroundColor Red }

# Check if running as admin (required for system env var)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires Administrator privileges to set system environment variables."
    Write-Host "`nPlease run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# Get current Ollama models location
$defaultPath = Join-Path $env:USERPROFILE ".ollama\models"
$currentPath = if ($env:OLLAMA_MODELS) { $env:OLLAMA_MODELS } else { $defaultPath }

Write-Host "`n=== Ollama Model Migration Script ===" -ForegroundColor Magenta
Write-Host ""
Write-Status "Current models location: $currentPath"
Write-Status "Target location: $TargetPath"

# Check if target drive exists
$targetDrive = Split-Path -Qualifier $TargetPath
if (-not (Test-Path $targetDrive)) {
    Write-Error "Drive $targetDrive does not exist!"
    exit 1
}

# Get drive info
$driveInfo = Get-PSDrive -Name ($targetDrive -replace ':','') -ErrorAction SilentlyContinue
if ($driveInfo) {
    $freeGB = [math]::Round($driveInfo.Free / 1GB, 2)
    Write-Status "Free space on $targetDrive : $freeGB GB"
}

# Calculate current models size
if (Test-Path $currentPath) {
    $modelsSize = (Get-ChildItem -Path $currentPath -Recurse -ErrorAction SilentlyContinue |
                   Measure-Object -Property Length -Sum).Sum
    $modelsSizeGB = [math]::Round($modelsSize / 1GB, 2)
    Write-Status "Current models size: $modelsSizeGB GB"

    if ($driveInfo -and $modelsSize -gt $driveInfo.Free) {
        Write-Error "Not enough free space on $targetDrive! Need $modelsSizeGB GB, have $freeGB GB"
        exit 1
    }
} else {
    Write-Warning "No models found at $currentPath"
    $modelsSizeGB = 0
}

Write-Host ""

# Step 1: Stop Ollama
Write-Status "Stopping Ollama..."

# Stop Ollama service if it exists
$ollamaService = Get-Service -Name "ollama" -ErrorAction SilentlyContinue
if ($ollamaService -and $ollamaService.Status -eq 'Running') {
    Write-Status "Stopping Ollama service..."
    Stop-Service -Name "ollama" -Force
    Write-Success "Ollama service stopped"
}

# Kill any ollama processes
$ollamaProcesses = Get-Process -Name "ollama*" -ErrorAction SilentlyContinue
if ($ollamaProcesses) {
    Write-Status "Stopping Ollama processes..."
    $ollamaProcesses | Stop-Process -Force
    Start-Sleep -Seconds 2
    Write-Success "Ollama processes stopped"
}

# Also check for ollama_llama_server (the inference process)
$llamaProcesses = Get-Process -Name "*llama*" -ErrorAction SilentlyContinue |
                  Where-Object { $_.Path -like "*ollama*" }
if ($llamaProcesses) {
    $llamaProcesses | Stop-Process -Force
    Start-Sleep -Seconds 1
}

Write-Success "Ollama stopped"

# Step 2: Create target folder
if (-not (Test-Path $TargetPath)) {
    Write-Status "Creating target folder: $TargetPath"
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    Write-Success "Target folder created"
} else {
    Write-Warning "Target folder already exists"
}

# Step 3: Move models
if (-not $SkipMove) {
    if (Test-Path $currentPath) {
        if ($currentPath -ne $TargetPath) {
            Write-Status "Moving models from $currentPath to $TargetPath..."
            Write-Status "This may take a while for large models..."

            # Use robocopy for better progress and reliability
            $robocopyArgs = @(
                $currentPath,
                $TargetPath,
                "/E",           # Copy subdirectories including empty ones
                "/MOVE",        # Move files (delete from source after copy)
                "/R:3",         # Retry 3 times
                "/W:5",         # Wait 5 seconds between retries
                "/MT:8",        # 8 threads
                "/NP",          # No progress percentage (cleaner output)
                "/NDL",         # No directory list
                "/NFL"          # No file list (less verbose)
            )

            $robocopyResult = & robocopy @robocopyArgs
            $robocopyExitCode = $LASTEXITCODE

            # Robocopy exit codes: 0-7 are success, 8+ are errors
            if ($robocopyExitCode -ge 8) {
                Write-Error "Robocopy failed with exit code $robocopyExitCode"
                Write-Host "You may need to manually move files and use -SkipMove flag"
                exit 1
            }

            Write-Success "Models moved successfully!"

            # Clean up empty source directory
            if (Test-Path $currentPath) {
                $remaining = Get-ChildItem -Path $currentPath -Recurse -ErrorAction SilentlyContinue
                if (-not $remaining) {
                    Remove-Item -Path $currentPath -Force -ErrorAction SilentlyContinue

                    # Also try to remove parent .ollama if empty
                    $parentOllama = Split-Path $currentPath -Parent
                    $parentRemaining = Get-ChildItem -Path $parentOllama -ErrorAction SilentlyContinue
                    if (-not $parentRemaining) {
                        Remove-Item -Path $parentOllama -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        } else {
            Write-Warning "Source and target are the same, skipping move"
        }
    } else {
        Write-Warning "No models to move (source doesn't exist)"
    }
} else {
    Write-Warning "Skipping file move (-SkipMove specified)"
}

# Step 4: Set OLLAMA_MODELS environment variable
Write-Status "Setting OLLAMA_MODELS environment variable..."

# Set system-wide (requires admin)
[System.Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $TargetPath, [System.EnvironmentVariableTarget]::Machine)

# Also set for current session
$env:OLLAMA_MODELS = $TargetPath

Write-Success "OLLAMA_MODELS set to: $TargetPath"

# Step 5: Restart Ollama
Write-Status "Starting Ollama..."

if ($ollamaService) {
    Start-Service -Name "ollama"
    Write-Success "Ollama service started"
} else {
    # Try to start ollama.exe directly
    $ollamaPath = Get-Command "ollama" -ErrorAction SilentlyContinue
    if ($ollamaPath) {
        Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
        Write-Success "Ollama started (process)"
    } else {
        Write-Warning "Could not find ollama.exe - please start Ollama manually"
    }
}

# Verify
Start-Sleep -Seconds 3
Write-Host ""
Write-Host "=== Migration Complete ===" -ForegroundColor Magenta
Write-Host ""
Write-Success "Models location: $TargetPath"
Write-Success "Environment variable OLLAMA_MODELS is set"
Write-Host ""

# Show current models
Write-Status "Verifying with 'ollama list'..."
Start-Sleep -Seconds 2

try {
    $models = & ollama list 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host $models
    } else {
        Write-Warning "Ollama may still be starting up. Try 'ollama list' in a moment."
    }
} catch {
    Write-Warning "Could not run 'ollama list'. Ollama may still be starting."
}

Write-Host ""
Write-Host "NOTE: You may need to restart your terminal for the environment variable to take effect." -ForegroundColor Yellow
Write-Host ""
