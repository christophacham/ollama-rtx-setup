<#
.SYNOPSIS
    Test SearXNG search engines

.DESCRIPTION
    Tests each enabled search engine in SearXNG by running a test query
    and reporting which engines are working.

.PARAMETER SearxngUrl
    SearXNG base URL (default: http://localhost:4000)

.PARAMETER TimeoutSeconds
    Timeout per engine in seconds (default: 10)

.PARAMETER TestQuery
    Query to test with (default: "test")

.EXAMPLE
    .\test-searxng-engines.ps1
    # Test all engines with defaults

.EXAMPLE
    .\test-searxng-engines.ps1 -TestQuery "hello world" -TimeoutSeconds 15
    # Custom query and timeout
#>

param(
    [string]$SearxngUrl = "http://localhost:4000",
    [int]$TimeoutSeconds = 10,
    [string]$TestQuery = "test"
)

# Output helpers
function Write-Status {
    param($Status, $Color, $Engine, $Details)
    $paddedEngine = $Engine.PadRight(20)
    Write-Host "  [$Status] " -NoNewline -ForegroundColor $Color
    Write-Host "$paddedEngine " -NoNewline
    Write-Host $Details -ForegroundColor Gray
}

function Write-Ok { param($Engine, $Details) Write-Status "OK" "Green" $Engine $Details }
function Write-Warn { param($Engine, $Details) Write-Status "WARN" "Yellow" $Engine $Details }
function Write-Err { param($Engine, $Details) Write-Status "ERR" "Red" $Engine $Details }

# Get enabled engines from settings.yml
function Get-EnabledEngines {
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }

    $settingsPath = Join-Path $scriptDir "searxng/settings.yml"

    if (-not (Test-Path $settingsPath)) {
        Write-Host "  Settings file not found: $settingsPath" -ForegroundColor Yellow
        Write-Host "  Falling back to common engines..." -ForegroundColor Yellow
        return @("duckduckgo", "google", "bing", "brave", "wikipedia")
    }

    $engines = @()
    $content = Get-Content $settingsPath -Raw

    # Parse YAML manually for engine names where disabled: false
    $inEngines = $false
    $currentEngine = $null
    $isDisabled = $false

    foreach ($line in (Get-Content $settingsPath)) {
        if ($line -match "^engines:") {
            $inEngines = $true
            continue
        }

        if ($inEngines) {
            # New engine block
            if ($line -match "^\s+-\s+name:\s+(.+)$") {
                # Save previous engine if it was enabled
                if ($currentEngine -and -not $isDisabled) {
                    $engines += $currentEngine
                }
                $currentEngine = $Matches[1].Trim()
                $isDisabled = $false
            }
            # Check disabled status
            elseif ($line -match "^\s+disabled:\s+(true|false)") {
                $isDisabled = $Matches[1] -eq "true"
            }
            # End of engines section
            elseif ($line -match "^[a-z]" -and $line -notmatch "^\s") {
                if ($currentEngine -and -not $isDisabled) {
                    $engines += $currentEngine
                }
                break
            }
        }
    }

    # Don't forget last engine
    if ($currentEngine -and -not $isDisabled) {
        $engines += $currentEngine
    }

    return $engines
}

# Test a single search engine
function Test-SearchEngine {
    param(
        [string]$Engine,
        [string]$BaseUrl,
        [string]$Query,
        [int]$Timeout
    )

    $url = "$BaseUrl/search?q=$([Uri]::EscapeDataString($Query))&format=json&engines=$Engine"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec $Timeout -ErrorAction Stop
        $stopwatch.Stop()

        $resultCount = 0
        if ($response.results) {
            $resultCount = $response.results.Count
        }

        return @{
            Engine = $Engine
            Success = $true
            ResultCount = $resultCount
            TimeMs = $stopwatch.ElapsedMilliseconds
            Error = $null
        }
    }
    catch {
        $stopwatch.Stop()
        $errorMsg = $_.Exception.Message

        # Check for timeout
        if ($errorMsg -match "timeout|timed out") {
            $errorMsg = "timeout after ${Timeout}s"
        }

        return @{
            Engine = $Engine
            Success = $false
            ResultCount = 0
            TimeMs = $stopwatch.ElapsedMilliseconds
            Error = $errorMsg
        }
    }
}

# Main
function Main {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  SearXNG Engine Test" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  URL:   $SearxngUrl" -ForegroundColor Gray
    Write-Host "  Query: `"$TestQuery`"" -ForegroundColor Gray
    Write-Host ""

    # Check if SearXNG is reachable
    Write-Host "Checking SearXNG availability..." -ForegroundColor Yellow
    try {
        $null = Invoke-RestMethod -Uri "$SearxngUrl/config" -Method Get -TimeoutSec 5 -ErrorAction Stop
        Write-Host "  [OK] SearXNG is running" -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERR] Cannot reach SearXNG at $SearxngUrl" -ForegroundColor Red
        Write-Host "  Make sure SearXNG is running (e.g., via Perplexica stack)" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Discovering enabled engines..." -ForegroundColor Yellow
    $engines = Get-EnabledEngines
    Write-Host "  Found $($engines.Count) engines: $($engines -join ', ')" -ForegroundColor Gray

    Write-Host ""
    Write-Host "Testing engines..." -ForegroundColor Yellow
    Write-Host ""

    $results = @()
    $working = 0
    $warnings = 0
    $errors = 0

    foreach ($engine in $engines) {
        $result = Test-SearchEngine -Engine $engine -BaseUrl $SearxngUrl -Query $TestQuery -Timeout $TimeoutSeconds
        $results += $result

        if ($result.Success) {
            if ($result.ResultCount -gt 0) {
                Write-Ok $engine "($($result.ResultCount) results, $([math]::Round($result.TimeMs/1000, 1))s)"
                $working++
            }
            else {
                Write-Warn $engine "(0 results - may be rate-limited)"
                $warnings++
            }
        }
        else {
            Write-Err $engine "($($result.Error))"
            $errors++
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    $summaryColor = if ($errors -eq 0) { "Green" } elseif ($working -gt 0) { "Yellow" } else { "Red" }
    Write-Host "  Summary: $working/$($engines.Count) engines working" -ForegroundColor $summaryColor
    if ($warnings -gt 0) {
        Write-Host "           $warnings with no results (rate-limited?)" -ForegroundColor Yellow
    }
    if ($errors -gt 0) {
        Write-Host "           $errors failed" -ForegroundColor Red
    }
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

Main
