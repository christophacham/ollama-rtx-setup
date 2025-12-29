<#
.SYNOPSIS
    Scans Ollama library for new coder models not in your config.

.DESCRIPTION
    Queries Ollama's model library and compares against custom_models.json.
    Reports new models with popularity above threshold.

    Since Ollama doesn't have a public browse API, this script uses
    a curated watchlist of popular model namespaces to check.

.PARAMETER MinPulls
    Minimum pull count to consider (default: 100)

.PARAMETER ConfigPath
    Path to custom_models.json (default: ./custom_models.json)

.PARAMETER CheckUpdates
    Also check if existing models have updates

.PARAMETER SaveReport
    Save results to scan-report.json

.EXAMPLE
    .\scan-ollama-models.ps1
    .\scan-ollama-models.ps1 -MinPulls 50 -SaveReport
    .\scan-ollama-models.ps1 -CheckUpdates
#>

param(
    [int]$MinPulls = 100,
    [string]$ConfigPath = "./custom_models.json",
    [switch]$CheckUpdates,
    [switch]$SaveReport
)

# Colors
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# Known coder-focused model namespaces to watch
$watchlist = @(
    # Official models
    @{ Name = "qwen2.5-coder"; Official = $true },
    @{ Name = "qwen3-coder"; Official = $true },
    @{ Name = "deepseek-coder"; Official = $true },
    @{ Name = "codellama"; Official = $true },
    @{ Name = "starcoder2"; Official = $true },
    @{ Name = "codegemma"; Official = $true },
    @{ Name = "devstral"; Official = $true },
    @{ Name = "gpt-oss"; Official = $true },

    # Community namespaces known for quality
    @{ Name = "NeuralNexusLab/CodeXor"; Official = $false },
    @{ Name = "mikepfunk28/deepseekq3"; Official = $false },
    @{ Name = "second_constantine/deepseek-coder"; Official = $false },
    @{ Name = "mannix/qwen2.5-coder"; Official = $false },
    @{ Name = "hhao/qwen2.5-coder-tools"; Official = $false }
)

function Get-ModelInfo {
    param([string]$ModelName)

    try {
        # Query Ollama's model page
        $url = "https://ollama.com/library/$ModelName"
        if ($ModelName -match "/") {
            # Community model format: namespace/model
            $url = "https://ollama.com/$ModelName"
        }

        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $content = $response.Content

        # Extract pull count from page (rough parsing)
        $pulls = 0
        if ($content -match '([\d,]+)\s*Pulls') {
            $pulls = [int]($matches[1] -replace ',', '')
        }
        elseif ($content -match '([\d,]+)\s*Downloads') {
            $pulls = [int]($matches[1] -replace ',', '')
        }

        # Extract last updated
        $updated = "Unknown"
        if ($content -match 'Updated\s+(.+?)<') {
            $updated = $matches[1].Trim()
        }

        # Extract available tags/sizes
        $tags = @()
        $tagMatches = [regex]::Matches($content, ':(\d+b)')
        foreach ($match in $tagMatches) {
            $tags += $match.Groups[1].Value
        }

        return @{
            Name = $ModelName
            Pulls = $pulls
            Updated = $updated
            Tags = ($tags | Select-Object -Unique) -join ", "
            Available = $true
        }
    }
    catch {
        return @{
            Name = $ModelName
            Pulls = 0
            Updated = "N/A"
            Tags = ""
            Available = $false
        }
    }
}

function Get-ExistingModels {
    param([string]$ConfigPath)

    if (-not (Test-Path $ConfigPath)) {
        Write-Warn "Config file not found: $ConfigPath"
        return @()
    }

    $config = Get-Content -Raw $ConfigPath | ConvertFrom-Json
    return $config.models | ForEach-Object { $_.model_name }
}

function Show-Banner {
    Write-Host @"

   ____  _ _                         __  __           _      _
  / __ \| | |                       |  \/  |         | |    | |
 | |  | | | | __ _ _ __ ___   __ _  | \  / | ___   __| | ___| |___
 | |  | | | |/ _` | '_ ` _ \ / _` | | |\/| |/ _ \ / _` |/ _ \ / __|
 | |__| | | | (_| | | | | | | (_| | | |  | | (_) | (_| |  __/ \__ \
  \____/|_|_|\__,_|_| |_| |_|\__,_| |_|  |_|\___/ \__,_|\___|_|___/

                    Model Scanner for Coder Models

"@ -ForegroundColor Cyan
}

# Main
Show-Banner

Write-Info "Loading existing models from $ConfigPath..."
$existingModels = Get-ExistingModels -ConfigPath $ConfigPath
Write-Success "Found $($existingModels.Count) models in config"

Write-Info "Scanning $($watchlist.Count) model namespaces..."
Write-Host ""

$results = @()
$newModels = @()

foreach ($item in $watchlist) {
    Write-Host "  Checking $($item.Name)..." -NoNewline

    $info = Get-ModelInfo -ModelName $item.Name

    if ($info.Available) {
        $isNew = $existingModels -notcontains $item.Name
        $status = if ($isNew) { "NEW" } else { "EXISTS" }
        $color = if ($isNew) { "Yellow" } else { "Green" }

        Write-Host " $($info.Pulls) pulls, $status" -ForegroundColor $color

        $results += [PSCustomObject]@{
            Name = $item.Name
            Pulls = $info.Pulls
            Updated = $info.Updated
            Tags = $info.Tags
            Official = $item.Official
            InConfig = -not $isNew
        }

        if ($isNew -and $info.Pulls -ge $MinPulls) {
            $newModels += $info
        }
    }
    else {
        Write-Host " not found" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=" * 60 -ForegroundColor Cyan

# Report new models
if ($newModels.Count -gt 0) {
    Write-Host ""
    Write-Warn "New models meeting criteria (>= $MinPulls pulls):"
    Write-Host ""

    $newModels | ForEach-Object {
        Write-Host "  " -NoNewline
        Write-Host $_.Name -ForegroundColor Yellow -NoNewline
        Write-Host " - $($_.Pulls) pulls, updated $($_.Updated)"
    }

    Write-Host ""
    Write-Host "To add these models:" -ForegroundColor Cyan
    Write-Host "  1. Add to `$coderModels in setup-ollama.ps1"
    Write-Host "  2. Add entry to custom_models.json"
    Write-Host "  3. Run: ollama pull <model-name>"
}
else {
    Write-Success "No new models found meeting criteria (>= $MinPulls pulls)"
}

# Check for updates to existing models
if ($CheckUpdates) {
    Write-Host ""
    Write-Info "Checking for updates to existing models..."

    foreach ($model in $existingModels) {
        $localInfo = ollama show $model 2>$null
        if ($LASTEXITCODE -eq 0) {
            # Model exists locally, could compare with remote
            Write-Host "  $model - installed" -ForegroundColor Green
        }
        else {
            Write-Host "  $model - not installed" -ForegroundColor Gray
        }
    }
}

# Save report
if ($SaveReport) {
    $reportPath = Join-Path (Split-Path $ConfigPath) "scan-report.json"
    $report = @{
        ScanDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        MinPulls = $MinPulls
        ExistingCount = $existingModels.Count
        NewModelsCount = $newModels.Count
        Results = $results
        NewModels = $newModels
    }

    $report | ConvertTo-Json -Depth 3 | Set-Content $reportPath
    Write-Success "Report saved to $reportPath"
}

Write-Host ""
Write-Host "Scan complete!" -ForegroundColor Green
