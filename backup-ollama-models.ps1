<#
.SYNOPSIS
    Ollama Models Backup & Restore Script
    Backup/restore your Ollama models to/from external storage

.DESCRIPTION
    - Backup: Copies all models from Ollama's default location to your chosen folder
    - Restore: Copies models from backup location back to Ollama's default location
    - Uses robocopy for reliable large file transfers with progress
    - Automatically stops Ollama before operations to prevent corruption

.NOTES
    Default Ollama models path: C:\Users\%username%\.ollama\models
    Models structure: blobs/ (model data) + manifests/ (metadata)
#>

param(
    [ValidateSet("Backup", "Restore", "Info")]
    [string]$Mode,
    [string]$Path,
    [switch]$SetEnvVar,
    [switch]$Help
)

# Colors
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# Banner
function Show-Banner {
    Write-Host @"

  ____             _                   ___  _ _
 | __ )  __ _  ___| | ___   _ _ __    / _ \| | | __ _ _ __ ___   __ _
 |  _ \ / _` |/ __| |/ / | | | '_ \  | | | | | |/ _` | '_ ` _ \ / _` |
 | |_) | (_| | (__|   <| |_| | |_) | | |_| | | | (_| | | | | | | (_| |
 |____/ \__,_|\___|_|\_\\__,_| .__/   \___/|_|_|\__,_|_| |_| |_|\__,_|
                             |_|
                    Model Backup & Restore Tool

"@ -ForegroundColor Cyan
}

# Help
function Show-Help {
    Write-Host @"
Usage: .\backup-ollama-models.ps1 [-Mode <Backup|Restore|Info>] [-Path <folder>] [-SetEnvVar] [-Help]

Modes:
    Backup    Copy models FROM Ollama TO your backup folder
    Restore   Copy models FROM backup folder TO Ollama
    Info      Show current Ollama storage info and model list

Options:
    -Path        Backup/restore folder path (will prompt if not provided)
    -SetEnvVar   After restore, set OLLAMA_MODELS env var to use backup location directly
    -Help        Show this help message

Examples:
    .\backup-ollama-models.ps1                           # Interactive mode
    .\backup-ollama-models.ps1 -Mode Backup              # Backup (prompt for path)
    .\backup-ollama-models.ps1 -Mode Backup -Path "F:\Backups\Ollama"
    .\backup-ollama-models.ps1 -Mode Restore -Path "F:\Backups\Ollama"
    .\backup-ollama-models.ps1 -Mode Info                # Show current storage info

Storage Location:
    Default: C:\Users\%username%\.ollama\models
    Custom:  Set OLLAMA_MODELS environment variable

Notes:
    - Ollama will be stopped automatically before backup/restore
    - Uses robocopy for reliable large file transfers
    - Progress is shown during copy operations
    - Original files are preserved (no deletion unless using -SetEnvVar)
"@
}

# Get Ollama models path
function Get-OllamaModelsPath {
    # Check if custom path is set via environment variable
    $customPath = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "User")
    if (-not $customPath) {
        $customPath = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "Machine")
    }

    if ($customPath -and (Test-Path $customPath)) {
        return $customPath
    }

    # Default path
    $defaultPath = Join-Path $env:USERPROFILE ".ollama\models"
    return $defaultPath
}

# Get folder size
function Get-FolderSize {
    param([string]$FolderPath)

    if (-not (Test-Path $FolderPath)) {
        return 0
    }

    $size = (Get-ChildItem -Path $FolderPath -Recurse -File -ErrorAction SilentlyContinue |
             Measure-Object -Property Length -Sum).Sum
    return $size
}

# Format bytes to human readable
function Format-Size {
    param([long]$Bytes)

    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes bytes"
}

# Stop Ollama
function Stop-Ollama {
    Write-Info "Stopping Ollama..."

    # Try graceful stop via tray icon simulation
    $ollamaProcess = Get-Process -Name "ollama*" -ErrorAction SilentlyContinue

    if ($ollamaProcess) {
        # Kill all Ollama processes
        Stop-Process -Name "ollama*" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        # Verify stopped
        $stillRunning = Get-Process -Name "ollama*" -ErrorAction SilentlyContinue
        if ($stillRunning) {
            Write-Warn "Ollama processes still running, forcing termination..."
            taskkill /F /IM "ollama.exe" 2>$null
            taskkill /F /IM "ollama app.exe" 2>$null
            Start-Sleep -Seconds 2
        }

        Write-Success "Ollama stopped"
    } else {
        Write-Info "Ollama is not running"
    }
}

# Show storage info
function Show-StorageInfo {
    $modelsPath = Get-OllamaModelsPath

    Write-Host ""
    Write-Host "Ollama Storage Information" -ForegroundColor Yellow
    Write-Host "==========================" -ForegroundColor Yellow
    Write-Host ""

    # Check for custom path
    $customPath = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "User")
    if (-not $customPath) {
        $customPath = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS", "Machine")
    }

    if ($customPath) {
        Write-Host "Custom Path (OLLAMA_MODELS): " -NoNewline
        Write-Host $customPath -ForegroundColor Green
    } else {
        Write-Host "Using default path (no OLLAMA_MODELS set)"
    }

    Write-Host "Active Models Path: " -NoNewline
    Write-Host $modelsPath -ForegroundColor Cyan
    Write-Host ""

    if (Test-Path $modelsPath) {
        $totalSize = Get-FolderSize -FolderPath $modelsPath
        Write-Host "Total Size: " -NoNewline
        Write-Host (Format-Size $totalSize) -ForegroundColor Yellow

        # Count blobs and manifests
        $blobsPath = Join-Path $modelsPath "blobs"
        $manifestsPath = Join-Path $modelsPath "manifests"

        if (Test-Path $blobsPath) {
            $blobCount = (Get-ChildItem -Path $blobsPath -File -ErrorAction SilentlyContinue).Count
            Write-Host "Blob files: $blobCount"
        }

        Write-Host ""

        # List models via ollama
        Write-Host "Installed Models:" -ForegroundColor Yellow
        try {
            $modelList = ollama list 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host $modelList
            } else {
                Write-Warn "Could not get model list (Ollama may not be running)"
            }
        } catch {
            Write-Warn "Could not query Ollama"
        }
    } else {
        Write-Warn "Models folder not found at: $modelsPath"
    }
}

# Backup models
function Backup-Models {
    param([string]$DestinationPath)

    $sourcePath = Get-OllamaModelsPath

    Write-Host ""
    Write-Host "BACKUP OPERATION" -ForegroundColor Yellow
    Write-Host "================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Source:      $sourcePath"
    Write-Host "Destination: $DestinationPath"
    Write-Host ""

    # Validate source
    if (-not (Test-Path $sourcePath)) {
        Write-Err "Source models folder not found: $sourcePath"
        return $false
    }

    # Get source size
    $sourceSize = Get-FolderSize -FolderPath $sourcePath
    Write-Info "Total size to backup: $(Format-Size $sourceSize)"

    # Check destination drive space
    $destDrive = Split-Path -Qualifier $DestinationPath
    if ($destDrive) {
        $drive = Get-PSDrive -Name $destDrive.TrimEnd(':') -ErrorAction SilentlyContinue
        if ($drive -and $drive.Free) {
            $freeSpace = $drive.Free
            Write-Info "Free space on $destDrive`: $(Format-Size $freeSpace)"

            if ($freeSpace -lt $sourceSize) {
                Write-Err "Not enough space on destination drive!"
                Write-Err "Required: $(Format-Size $sourceSize), Available: $(Format-Size $freeSpace)"
                return $false
            }
        }
    }

    # Create destination if needed
    if (-not (Test-Path $DestinationPath)) {
        Write-Info "Creating destination folder..."
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }

    # Stop Ollama
    Stop-Ollama

    # Perform backup using robocopy
    Write-Host ""
    Write-Info "Starting backup with robocopy..."
    Write-Host "This may take a while for large models..." -ForegroundColor Gray
    Write-Host ""

    # Robocopy with progress
    # /E = copy subdirectories including empty ones
    # /Z = restartable mode (resume interrupted copies)
    # /ETA = show estimated time of arrival
    # /R:3 = retry 3 times
    # /W:5 = wait 5 seconds between retries
    $robocopyArgs = @(
        "`"$sourcePath`"",
        "`"$DestinationPath`"",
        "/E",
        "/Z",
        "/ETA",
        "/R:3",
        "/W:5",
        "/NP",
        "/NDL"
    )

    $robocopyCmd = "robocopy $($robocopyArgs -join ' ')"
    Write-Host "Running: robocopy `"$sourcePath`" `"$DestinationPath`" /E /Z /ETA" -ForegroundColor Gray
    Write-Host ""

    # Execute robocopy
    & robocopy $sourcePath $DestinationPath /E /Z /ETA /R:3 /W:5

    $exitCode = $LASTEXITCODE

    # Robocopy exit codes: 0-7 are success, 8+ are errors
    if ($exitCode -lt 8) {
        Write-Host ""
        Write-Success "Backup completed successfully!"

        # Verify
        $destSize = Get-FolderSize -FolderPath $DestinationPath
        Write-Host ""
        Write-Host "Verification:" -ForegroundColor Yellow
        Write-Host "  Source size:      $(Format-Size $sourceSize)"
        Write-Host "  Destination size: $(Format-Size $destSize)"

        if ($destSize -ge ($sourceSize * 0.99)) {
            Write-Success "Size verification passed"
        } else {
            Write-Warn "Size mismatch - some files may not have copied"
        }

        return $true
    } else {
        Write-Err "Backup failed with robocopy exit code: $exitCode"
        return $false
    }
}

# Restore models
function Restore-Models {
    param([string]$SourcePath, [switch]$SetEnvironmentVariable)

    $destPath = Get-OllamaModelsPath

    # If setting env var, we'll use the source as the new models location
    if ($SetEnvironmentVariable) {
        Write-Host ""
        Write-Host "SET OLLAMA_MODELS MODE" -ForegroundColor Yellow
        Write-Host "======================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Instead of copying, this will set OLLAMA_MODELS environment variable"
        Write-Host "to point directly to your backup location."
        Write-Host ""
        Write-Host "New models path will be: $SourcePath"
        Write-Host ""

        # Validate source has models
        $blobsPath = Join-Path $SourcePath "blobs"
        if (-not (Test-Path $blobsPath)) {
            Write-Err "No valid Ollama models found at: $SourcePath"
            Write-Err "Expected to find 'blobs' subfolder"
            return $false
        }

        # Stop Ollama
        Stop-Ollama

        # Set environment variable
        Write-Info "Setting OLLAMA_MODELS environment variable..."
        [Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $SourcePath, "User")

        Write-Success "OLLAMA_MODELS set to: $SourcePath"
        Write-Host ""
        Write-Warn "You need to restart Ollama for changes to take effect."
        Write-Host "Run: ollama serve"

        return $true
    }

    Write-Host ""
    Write-Host "RESTORE OPERATION" -ForegroundColor Yellow
    Write-Host "=================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Source:      $SourcePath"
    Write-Host "Destination: $destPath"
    Write-Host ""

    # Validate source
    if (-not (Test-Path $SourcePath)) {
        Write-Err "Backup folder not found: $SourcePath"
        return $false
    }

    # Check for valid backup (should have blobs folder)
    $blobsPath = Join-Path $SourcePath "blobs"
    if (-not (Test-Path $blobsPath)) {
        Write-Err "Invalid backup - no 'blobs' folder found in: $SourcePath"
        return $false
    }

    # Get source size
    $sourceSize = Get-FolderSize -FolderPath $SourcePath
    Write-Info "Total size to restore: $(Format-Size $sourceSize)"

    # Stop Ollama
    Stop-Ollama

    # Create destination parent if needed
    $destParent = Split-Path -Parent $destPath
    if (-not (Test-Path $destParent)) {
        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    }

    # Perform restore using robocopy
    Write-Host ""
    Write-Info "Starting restore with robocopy..."
    Write-Host "This may take a while for large models..." -ForegroundColor Gray
    Write-Host ""

    Write-Host "Running: robocopy `"$SourcePath`" `"$destPath`" /E /Z /ETA" -ForegroundColor Gray
    Write-Host ""

    & robocopy $SourcePath $destPath /E /Z /ETA /R:3 /W:5

    $exitCode = $LASTEXITCODE

    if ($exitCode -lt 8) {
        Write-Host ""
        Write-Success "Restore completed successfully!"

        # Verify
        $destSize = Get-FolderSize -FolderPath $destPath
        Write-Host ""
        Write-Host "Verification:" -ForegroundColor Yellow
        Write-Host "  Source size:      $(Format-Size $sourceSize)"
        Write-Host "  Destination size: $(Format-Size $destSize)"

        Write-Host ""
        Write-Info "You can now start Ollama: ollama serve"

        return $true
    } else {
        Write-Err "Restore failed with robocopy exit code: $exitCode"
        return $false
    }
}

# Ask user for path
function Get-UserPath {
    param([string]$PromptMessage)

    Write-Host ""
    Write-Host $PromptMessage -ForegroundColor Yellow
    Write-Host "Example: F:\Backups\OllamaModels"
    Write-Host ""
    $path = Read-Host "Enter path"

    return $path.Trim('"').Trim("'").Trim()
}

# Ask user for mode
function Get-UserMode {
    Write-Host ""
    Write-Host "What would you like to do?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Backup  - Copy models TO an external location"
    Write-Host "  [2] Restore - Copy models FROM a backup location"
    Write-Host "  [3] Info    - Show current storage information"
    Write-Host "  [4] Exit"
    Write-Host ""

    $choice = Read-Host "Enter choice (1-4)"

    switch ($choice) {
        "1" { return "Backup" }
        "2" { return "Restore" }
        "3" { return "Info" }
        "4" { return "Exit" }
        default { return $null }
    }
}

# Main
function Main {
    Show-Banner

    if ($Help) {
        Show-Help
        return
    }

    # Determine mode
    $selectedMode = $Mode
    if (-not $selectedMode) {
        $selectedMode = Get-UserMode
        if (-not $selectedMode -or $selectedMode -eq "Exit") {
            Write-Host "Exiting..."
            return
        }
    }

    # Handle modes
    switch ($selectedMode) {
        "Info" {
            Show-StorageInfo
        }

        "Backup" {
            $backupPath = $Path
            if (-not $backupPath) {
                $backupPath = Get-UserPath -PromptMessage "Enter DESTINATION folder for backup:"
            }

            if (-not $backupPath) {
                Write-Err "No path provided"
                return
            }

            # Confirm
            Write-Host ""
            Write-Host "Ready to backup?" -ForegroundColor Yellow
            Write-Host "  From: $(Get-OllamaModelsPath)"
            Write-Host "  To:   $backupPath"
            Write-Host ""
            $confirm = Read-Host "Continue? (Y/N)"

            if ($confirm -eq "Y" -or $confirm -eq "y") {
                Backup-Models -DestinationPath $backupPath
            } else {
                Write-Host "Cancelled."
            }
        }

        "Restore" {
            $restorePath = $Path
            if (-not $restorePath) {
                $restorePath = Get-UserPath -PromptMessage "Enter SOURCE folder containing backup:"
            }

            if (-not $restorePath) {
                Write-Err "No path provided"
                return
            }

            # Ask about env var option
            Write-Host ""
            Write-Host "Restore options:" -ForegroundColor Yellow
            Write-Host "  [1] Copy files to Ollama default location"
            Write-Host "  [2] Set OLLAMA_MODELS to use backup location directly (no copy)"
            Write-Host ""
            $restoreChoice = Read-Host "Enter choice (1-2)"

            $useEnvVar = $restoreChoice -eq "2"

            # Confirm
            Write-Host ""
            Write-Host "Ready to restore?" -ForegroundColor Yellow
            Write-Host "  From: $restorePath"
            if ($useEnvVar) {
                Write-Host "  Mode: Set OLLAMA_MODELS environment variable"
            } else {
                Write-Host "  To:   $(Get-OllamaModelsPath)"
            }
            Write-Host ""
            $confirm = Read-Host "Continue? (Y/N)"

            if ($confirm -eq "Y" -or $confirm -eq "y") {
                Restore-Models -SourcePath $restorePath -SetEnvironmentVariable:$useEnvVar
            } else {
                Write-Host "Cancelled."
            }
        }
    }

    Write-Host ""
}

# Run
Main
