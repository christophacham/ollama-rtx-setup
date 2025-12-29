<#
.SYNOPSIS
    Optimizes Ollama models to run 100% on GPU (0% CPU) for RTX 5090 (32GB VRAM).

.DESCRIPTION
    This script tests each installed Ollama model and creates optimized "-5090" variants
    for any model that shows CPU offloading. The optimized variants use:
    - num_gpu 99 (force all layers to GPU)
    - Calculated num_ctx (context size that fits in VRAM)

.PARAMETER Model
    Optimize a specific model instead of all models.

.PARAMETER List
    Show optimization status of all models without making changes.

.PARAMETER Undo
    Remove all -5090 variants created by this script.

.PARAMETER ContextSize
    Override the auto-calculated context size.

.PARAMETER Force
    Re-optimize models even if they already have -5090 variants.

.EXAMPLE
    .\optimize-ollama-5090.ps1
    # Optimize all installed models

.EXAMPLE
    .\optimize-ollama-5090.ps1 -Model "deepseek-r1:32b"
    # Optimize a specific model

.EXAMPLE
    .\optimize-ollama-5090.ps1 -List
    # Show optimization status

.EXAMPLE
    .\optimize-ollama-5090.ps1 -Undo
    # Remove all -5090 variants

.EXAMPLE
    .\optimize-ollama-5090.ps1 -DeleteOriginal
    # Optimize all models and delete originals after successful optimization (prompts first)

.EXAMPLE
    .\optimize-ollama-5090.ps1 -Cleanup
    # Find all models that have both base and -5090 versions, offer to delete base versions
#>

[CmdletBinding()]
param(
    [string]$Model,
    [switch]$List,
    [switch]$Undo,
    [switch]$Cleanup,          # Remove original models where -5090 variant exists
    [int]$ContextSize = 0,
    [switch]$Force,
    [switch]$DeleteOriginal,   # Delete original model after successful optimization
    [switch]$NoPrompt          # Don't ask, just delete originals (use with -DeleteOriginal)
)

$ErrorActionPreference = "Stop"
$script:JsonPath = Join-Path $PSScriptRoot "5090-optimized.json"

# Colors for output
function Write-Status { param($msg) Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline; Write-Host $msg }
function Write-Success { param($msg) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Warning { param($msg) Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Error { param($msg) Write-Host "[ERR] " -ForegroundColor Red -NoNewline; Write-Host $msg }

# Detect GPU VRAM using nvidia-smi
function Get-GpuVram {
    try {
        $vramMB = (nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits |
                   Select-Object -First 1) -as [int]
        return [math]::Round($vramMB / 1024, 1)
    } catch {
        Write-Error "Could not detect GPU. Is nvidia-smi available?"
        return 0
    }
}

# Get model size in GB from ollama list output
function Get-ModelSizeGB {
    param([string]$SizeStr)

    if ($SizeStr -match "(\d+\.?\d*)\s*(GB|MB)") {
        $value = [double]$Matches[1]
        $unit = $Matches[2]
        if ($unit -eq "MB") { $value = $value / 1024 }
        return [math]::Round($value, 1)
    }
    return 0
}

# Calculate optimal context size based on model size and VRAM
function Get-OptimalContext {
    param(
        [double]$ModelSizeGB,
        [double]$VramGB
    )

    $available = $VramGB - $ModelSizeGB - 2  # 2GB buffer for system

    if ($available -ge 20) { return 65536 }
    if ($available -ge 12) { return 32768 }
    if ($available -ge 6)  { return 16384 }
    return 8192
}

# Parse ollama list output into structured data
function Get-InstalledModels {
    $output = ollama list 2>&1
    $models = @()

    # Skip header line
    $lines = $output -split "`n" | Select-Object -Skip 1

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # Parse: NAME    ID    SIZE    MODIFIED
        # Format varies, use regex to extract
        if ($line -match "^(\S+)\s+(\S+)\s+(\d+\.?\d*\s*[GMK]B)\s+(.+)$") {
            $models += @{
                Name = $Matches[1]
                ID = $Matches[2]
                Size = $Matches[3]
                SizeGB = Get-ModelSizeGB $Matches[3]
                Modified = $Matches[4].Trim()
            }
        }
    }

    return $models
}

# Load model and check CPU/GPU split from ollama ps
function Test-ModelGpuUsage {
    param([string]$ModelName)

    Write-Host "  Loading model..." -ForegroundColor Gray

    # Send a simple prompt to load the model
    $null = "hi" | ollama run $ModelName 2>&1

    # Give it a moment to settle
    Start-Sleep -Seconds 2

    # Check ollama ps
    $psOutput = ollama ps 2>&1

    # Parse the output for CPU/GPU percentages
    # Format: NAME    ID    SIZE    PROCESSOR    UNTIL
    # PROCESSOR can be: "100% GPU", "61%/39% CPU/GPU", etc.

    foreach ($line in ($psOutput -split "`n")) {
        if ($line -match $ModelName.Replace(":", "\:")) {
            if ($line -match "(\d+)%/(\d+)%\s*CPU/GPU") {
                return @{ CPU = [int]$Matches[1]; GPU = [int]$Matches[2] }
            }
            elseif ($line -match "(\d+)%\s*GPU") {
                return @{ CPU = 0; GPU = [int]$Matches[1] }
            }
            elseif ($line -match "(\d+)%\s*CPU") {
                return @{ CPU = [int]$Matches[1]; GPU = 0 }
            }
        }
    }

    # Model might have unloaded, return unknown
    return @{ CPU = -1; GPU = -1 }
}

# Unload all models to free VRAM
function Clear-LoadedModels {
    # Stop ollama and restart to clear loaded models
    $psOutput = ollama ps 2>&1
    foreach ($line in ($psOutput -split "`n" | Select-Object -Skip 1)) {
        if ($line -match "^(\S+)") {
            $modelName = $Matches[1]
            if ($modelName -and $modelName -ne "NAME") {
                # Use ollama stop if available, otherwise just continue
                try {
                    ollama stop $modelName 2>&1 | Out-Null
                } catch {
                    # Older ollama versions don't have stop
                }
            }
        }
    }
    Start-Sleep -Seconds 1
}

# Create optimized model variant
function New-OptimizedModel {
    param(
        [string]$OriginalModel,
        [int]$NumCtx,
        [int]$NumGpu = 99
    )

    $optimizedName = "$OriginalModel-5090"

    # Create modelfile
    $modelfile = @"
FROM $OriginalModel
PARAMETER num_gpu $NumGpu
PARAMETER num_ctx $NumCtx
"@

    $tempFile = Join-Path $env:TEMP "ollama-modelfile-5090.txt"
    $modelfile | Out-File $tempFile -Encoding ASCII

    Write-Host "  Creating $optimizedName with num_ctx=$NumCtx, num_gpu=$NumGpu" -ForegroundColor Gray

    $result = ollama create $optimizedName -f $tempFile 2>&1
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -eq 0) {
        return $optimizedName
    }
    return $null
}

# Load/save optimization tracking JSON
function Get-OptimizationData {
    if (Test-Path $script:JsonPath) {
        return Get-Content $script:JsonPath | ConvertFrom-Json
    }
    return @{ optimized = @() }
}

function Save-OptimizationData {
    param($Data)
    $Data | ConvertTo-Json -Depth 10 | Out-File $script:JsonPath -Encoding UTF8
}

# Main optimization logic for a single model
function Optimize-Model {
    param(
        [hashtable]$ModelInfo,
        [double]$VramGB,
        [int]$OverrideContext = 0
    )

    $name = $ModelInfo.Name
    $sizeGB = $ModelInfo.SizeGB

    # Skip if this is already a -5090 variant
    if ($name -match "-5090$") {
        Write-Host "  Skipping (already optimized variant)" -ForegroundColor DarkGray
        return $null
    }

    # Check if -5090 variant already exists (unless Force)
    if (-not $Force) {
        $existingModels = Get-InstalledModels
        $variantExists = $existingModels | Where-Object { $_.Name -eq "$name-5090" }
        if ($variantExists) {
            Write-Host "  Skipping (variant exists, use -Force to recreate)" -ForegroundColor DarkGray
            return $null
        }
    }

    # Clear any loaded models first
    Clear-LoadedModels

    # Test the model
    $usage = Test-ModelGpuUsage $name

    if ($usage.CPU -eq -1) {
        Write-Warning "  Could not determine GPU usage (model may have unloaded)"
        return $null
    }

    Write-Host "  CPU: $($usage.CPU)% / GPU: $($usage.GPU)%" -NoNewline

    if ($usage.CPU -eq 0) {
        Write-Host " - ALREADY OPTIMIZED" -ForegroundColor Green
        return $null
    }

    Write-Host " - NEEDS OPTIMIZATION" -ForegroundColor Yellow

    # Calculate optimal context
    $numCtx = if ($OverrideContext -gt 0) { $OverrideContext } else { Get-OptimalContext $sizeGB $VramGB }

    # Create optimized variant
    $optimizedName = New-OptimizedModel $name $numCtx

    if ($optimizedName) {
        # Clear and re-test
        Clear-LoadedModels
        $newUsage = Test-ModelGpuUsage $optimizedName

        Write-Host "  Re-test: CPU: $($newUsage.CPU)% / GPU: $($newUsage.GPU)%" -NoNewline

        if ($newUsage.CPU -eq 0) {
            Write-Host " - OK" -ForegroundColor Green
        } else {
            Write-Host " - Still using CPU (try smaller context)" -ForegroundColor Yellow
        }

        return @{
            original = $name
            optimized = $optimizedName
            num_ctx = $numCtx
            num_gpu = 99
            original_size_gb = $sizeGB
            cpu_before = $usage.CPU
            cpu_after = $newUsage.CPU
            date = (Get-Date).ToString("yyyy-MM-dd")
        }
    }

    return $null
}

# List optimization status
function Show-OptimizationStatus {
    param([double]$VramGB)

    Write-Host ""
    Write-Status "GPU: RTX with $($VramGB)GB VRAM"
    Write-Host ""

    $models = Get-InstalledModels
    $data = Get-OptimizationData

    Write-Host "Model".PadRight(40) "Size".PadRight(10) "Status" -ForegroundColor Cyan
    Write-Host ("-" * 70)

    foreach ($model in $models) {
        $name = $model.Name
        $size = $model.Size

        # Skip -5090 variants in main list
        if ($name -match "-5090$") { continue }

        $status = "Not tested"
        $color = "Gray"

        # Check if variant exists
        $variant = $models | Where-Object { $_.Name -eq "$name-5090" }
        if ($variant) {
            $status = "Optimized (-5090 exists)"
            $color = "Green"
        }

        # Check tracking data
        $tracked = $data.optimized | Where-Object { $_.original -eq $name }
        if ($tracked) {
            $status = "Optimized (ctx=$($tracked.num_ctx))"
            $color = "Green"
        }

        Write-Host $name.PadRight(40) $size.PadRight(10) -NoNewline
        Write-Host $status -ForegroundColor $color
    }

    # Show -5090 variants
    $variants = $models | Where-Object { $_.Name -match "-5090$" }
    if ($variants.Count -gt 0) {
        Write-Host ""
        Write-Host "Optimized Variants:" -ForegroundColor Cyan
        foreach ($v in $variants) {
            Write-Host "  $($v.Name)" -ForegroundColor Green
        }
    }
}

# Remove all -5090 variants
function Remove-OptimizedVariants {
    $models = Get-InstalledModels
    $variants = $models | Where-Object { $_.Name -match "-5090$" }

    if ($variants.Count -eq 0) {
        Write-Status "No -5090 variants found"
        return
    }

    Write-Status "Removing $($variants.Count) optimized variant(s)..."

    foreach ($variant in $variants) {
        Write-Host "  Removing $($variant.Name)..." -NoNewline
        ollama rm $variant.Name 2>&1 | Out-Null
        Write-Host " done" -ForegroundColor Green
    }

    # Clear tracking data
    if (Test-Path $script:JsonPath) {
        Remove-Item $script:JsonPath -Force
    }

    Write-Success "Removed all -5090 variants"
}

# Delete a specific model
function Remove-OriginalModel {
    param([string]$ModelName)

    Write-Host "  Deleting original $ModelName..." -NoNewline
    try {
        $env:TERM = "dumb"  # Disable ANSI escape codes
        $null = ollama rm $ModelName 2>&1
        Write-Host " done" -ForegroundColor Green
        return $true
    } catch {
        Write-Host " failed" -ForegroundColor Red
        return $false
    }
}

# Cleanup: Find all base models that have -5090 variants and offer to delete them
function Invoke-Cleanup {
    $models = Get-InstalledModels

    # Find all -5090 variants
    $variants = $models | Where-Object { $_.Name -match "-5090$" }

    if ($variants.Count -eq 0) {
        Write-Status "No -5090 variants found. Run optimization first."
        return
    }

    # Find originals that also exist
    $toDelete = @()
    foreach ($variant in $variants) {
        $baseName = $variant.Name -replace "-5090$", ""
        $original = $models | Where-Object { $_.Name -eq $baseName }
        if ($original) {
            $toDelete += $original
        }
    }

    if ($toDelete.Count -eq 0) {
        Write-Success "No duplicate base models found - all originals already removed!"
        return
    }

    Write-Host ""
    Write-Host "Found $($toDelete.Count) base model(s) with existing -5090 variants:" -ForegroundColor Yellow
    Write-Host ""

    $totalSize = 0
    foreach ($model in $toDelete) {
        $sizeGB = $model.SizeGB
        $totalSize += $sizeGB
        Write-Host "  $($model.Name)".PadRight(45) "$($model.Size)" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "Total space to free: " -NoNewline
    Write-Host "$([math]::Round($totalSize, 1)) GB" -ForegroundColor Green
    Write-Host ""

    if (-not $NoPrompt) {
        $response = Read-Host "Delete these $($toDelete.Count) original model(s)? [y/N]"
        if ($response -notmatch "^[Yy]") {
            Write-Status "Cleanup cancelled"
            return
        }
    }

    Write-Host ""
    $deleted = 0
    foreach ($model in $toDelete) {
        if (Remove-OriginalModel $model.Name) {
            $deleted++
        }
    }

    Write-Host ""
    Write-Success "Deleted $deleted of $($toDelete.Count) original model(s)"
    Write-Host "Freed approximately $([math]::Round($totalSize, 1)) GB" -ForegroundColor Green
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "  Ollama GPU Optimizer for RTX 5090 (32GB VRAM)" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""

    # Detect GPU
    $vramGB = Get-GpuVram
    if ($vramGB -eq 0) {
        Write-Error "No NVIDIA GPU detected. Exiting."
        exit 1
    }
    Write-Status "Detected GPU with $($vramGB)GB VRAM"

    # Handle -List
    if ($List) {
        Show-OptimizationStatus $vramGB
        return
    }

    # Handle -Undo
    if ($Undo) {
        Remove-OptimizedVariants
        return
    }

    # Handle -Cleanup
    if ($Cleanup) {
        Invoke-Cleanup
        return
    }

    # Get models to optimize
    $models = Get-InstalledModels

    if ($Model) {
        # Single model mode
        $targetModel = $models | Where-Object { $_.Name -eq $Model }
        if (-not $targetModel) {
            Write-Error "Model '$Model' not found. Run 'ollama list' to see available models."
            exit 1
        }
        $models = @($targetModel)
    } else {
        # Filter out -5090 variants
        $models = $models | Where-Object { $_.Name -notmatch "-5090$" }
    }

    Write-Status "Found $($models.Count) model(s) to test"
    Write-Host ""

    # Load existing tracking data
    $data = Get-OptimizationData
    if (-not $data.optimized) { $data.optimized = @() }

    $optimizedCount = 0
    $alreadyOptimized = 0
    $failed = 0

    foreach ($modelInfo in $models) {
        Write-Host "Testing $($modelInfo.Name) ($($modelInfo.Size))..." -ForegroundColor White

        $result = Optimize-Model $modelInfo $vramGB $ContextSize

        if ($result) {
            # Add to tracking data
            $data.optimized = @($data.optimized | Where-Object { $_.original -ne $result.original })
            $data.optimized += $result
            $optimizedCount++

            # Delete original if requested and optimization was successful (0% CPU)
            if ($DeleteOriginal -and $result.cpu_after -eq 0) {
                $doDelete = $NoPrompt
                if (-not $NoPrompt) {
                    $response = Read-Host "  Delete original $($result.original)? [y/N]"
                    $doDelete = $response -match "^[Yy]"
                }
                if ($doDelete) {
                    Remove-OriginalModel $result.original | Out-Null
                }
            }
        } elseif ($result -eq $null) {
            $alreadyOptimized++
        } else {
            $failed++
        }

        Write-Host ""
    }

    # Save tracking data
    Save-OptimizationData $data

    # Clear loaded models at the end
    Clear-LoadedModels

    # Summary
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "  Summary" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Tested:            $($models.Count) model(s)"
    Write-Host "  Newly optimized:   $optimizedCount" -ForegroundColor $(if ($optimizedCount -gt 0) { "Green" } else { "White" })
    Write-Host "  Already optimized: $alreadyOptimized" -ForegroundColor Gray
    if ($failed -gt 0) {
        Write-Host "  Failed:            $failed" -ForegroundColor Red
    }
    Write-Host ""

    if ($optimizedCount -gt 0) {
        Write-Success "Created $optimizedCount optimized variant(s)"
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  ollama run <model>-5090" -ForegroundColor Gray
        Write-Host "  Example: ollama run deepseek-r1:32b-5090" -ForegroundColor Gray
    }
}

Main
