<#
.SYNOPSIS
    Bandwidth limiter for Ollama downloads
    Requires Administrator privileges

.DESCRIPTION
    Limits Ollama download bandwidth to prevent network saturation.
    Uses Windows QoS policies to throttle ollama.exe.

    Run with -Limit to enable throttling (tests speed first)
    Run with -Unlimit to remove throttling

.PARAMETER Limit
    Enable bandwidth limiting (default: 50% of tested speed)

.PARAMETER Unlimit
    Remove bandwidth limiting

.PARAMETER Percent
    Percentage of bandwidth to allow (default: 50)

.PARAMETER SkipSpeedTest
    Skip speed test and use specified -SpeedMbps value

.PARAMETER SpeedMbps
    Manual speed in Mbps (use with -SkipSpeedTest)

.EXAMPLE
    .\limit-ollama-bandwidth.ps1 -Limit
    .\limit-ollama-bandwidth.ps1 -Limit -Percent 30
    .\limit-ollama-bandwidth.ps1 -Unlimit
#>

param(
    [switch]$Limit,
    [switch]$Unlimit,
    [int]$Percent = 50,
    [switch]$SkipSpeedTest,
    [int]$SpeedMbps = 100
)

$PolicyName = "OllamaDownloadLimit"

# Colors
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# Check admin rights
function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Test download speed
function Test-DownloadSpeed {
    param(
        [string]$TestUrl = "http://speedtest.tele2.net/10MB.zip",
        [int]$FileSizeMB = 10
    )

    Write-Info "Testing download speed..."
    Write-Host "  Downloading ${FileSizeMB}MB test file..." -ForegroundColor Gray

    $tempFile = "$env:TEMP\speedtest_$(Get-Random).bin"

    try {
        $startTime = Get-Date

        # Use BitsTransfer for more accurate measurement
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($TestUrl, $tempFile)

        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds

        if (Test-Path $tempFile) {
            $fileSize = (Get-Item $tempFile).Length
            $speedMbps = [math]::Round(($fileSize / 1MB) / $duration * 8, 2)
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            return $speedMbps
        }
    } catch {
        Write-Warn "Speed test failed: $_"
        # Fallback to smaller file
        try {
            $startTime = Get-Date
            Invoke-WebRequest -Uri "http://speedtest.tele2.net/1MB.zip" -OutFile $tempFile -UseBasicParsing
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            $speedMbps = [math]::Round(1 / $duration * 8, 2)
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            return $speedMbps
        } catch {
            Write-Warn "Fallback speed test also failed. Using default 100 Mbps."
            return 100
        }
    }

    return 100
}

# Get Ollama executable path
function Get-OllamaPath {
    $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
    if ($ollamaCmd) {
        return $ollamaCmd.Source
    }

    # Common locations
    $commonPaths = @(
        "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe",
        "$env:ProgramFiles\Ollama\ollama.exe",
        "C:\Program Files\Ollama\ollama.exe"
    )

    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

# Check if QoS policy exists
function Test-QosPolicyExists {
    param([string]$Name)

    try {
        $policy = Get-NetQosPolicy -Name $Name -ErrorAction SilentlyContinue
        return $null -ne $policy
    } catch {
        return $false
    }
}

# Apply bandwidth limit
function Set-BandwidthLimit {
    param(
        [int]$ThrottleRateMbps,
        [string]$AppPath
    )

    Write-Info "Applying bandwidth limit of ${ThrottleRateMbps} Mbps to Ollama..."

    # Remove existing policy if present
    if (Test-QosPolicyExists -Name $PolicyName) {
        Write-Info "Removing existing policy..."
        Remove-NetQosPolicy -Name $PolicyName -Confirm:$false -ErrorAction SilentlyContinue
    }

    try {
        # Create QoS policy for the application
        # ThrottleRateActionBitsPerSecond expects bits per second
        $throttleBps = $ThrottleRateMbps * 1000000

        New-NetQosPolicy -Name $PolicyName `
            -AppPathNameMatchCondition "ollama.exe" `
            -ThrottleRateActionBitsPerSecond $throttleBps `
            -PolicyStore ActiveStore `
            -ErrorAction Stop

        Write-Success "Bandwidth limit applied: ${ThrottleRateMbps} Mbps"
        Write-Host ""
        Write-Host "  Policy Name: $PolicyName" -ForegroundColor Gray
        Write-Host "  Target: ollama.exe" -ForegroundColor Gray
        Write-Host "  Limit: ${ThrottleRateMbps} Mbps (${throttleBps} bps)" -ForegroundColor Gray
        Write-Host ""
        Write-Warn "Remember to run with -Unlimit when done downloading!"

        return $true
    } catch {
        Write-Err "Failed to apply QoS policy: $_"
        Write-Host ""
        Write-Host "Alternative: Set environment variable before downloading:" -ForegroundColor Yellow
        Write-Host '  $env:OLLAMA_DOWNLOAD_CONN = 1' -ForegroundColor Cyan
        Write-Host "  This limits to single connection (fair share with other traffic)" -ForegroundColor Gray
        return $false
    }
}

# Remove bandwidth limit
function Remove-BandwidthLimit {
    Write-Info "Removing bandwidth limit..."

    if (-not (Test-QosPolicyExists -Name $PolicyName)) {
        Write-Warn "No bandwidth limit policy found. Nothing to remove."
        return $true
    }

    try {
        Remove-NetQosPolicy -Name $PolicyName -Confirm:$false -ErrorAction Stop
        Write-Success "Bandwidth limit removed successfully!"
        Write-Host ""
        Write-Host "  Ollama downloads will now use full bandwidth." -ForegroundColor Gray
        return $true
    } catch {
        Write-Err "Failed to remove QoS policy: $_"
        return $false
    }
}

# Show current status
function Show-Status {
    Write-Host ""
    Write-Host "=== Ollama Bandwidth Limiter ===" -ForegroundColor Cyan
    Write-Host ""

    if (Test-QosPolicyExists -Name $PolicyName) {
        $policy = Get-NetQosPolicy -Name $PolicyName
        $limitMbps = [math]::Round($policy.ThrottleRateActionBitsPerSecond / 1000000, 2)
        Write-Host "  Status: " -NoNewline
        Write-Host "LIMITED" -ForegroundColor Yellow
        Write-Host "  Current Limit: ${limitMbps} Mbps" -ForegroundColor Gray
    } else {
        Write-Host "  Status: " -NoNewline
        Write-Host "UNLIMITED" -ForegroundColor Green
        Write-Host "  Ollama using full bandwidth" -ForegroundColor Gray
    }
    Write-Host ""
}

# Interactive menu
function Show-Menu {
    Write-Host ""
    Write-Host "=== Ollama Bandwidth Limiter ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script limits Ollama download bandwidth to prevent"
    Write-Host "network saturation when downloading large models."
    Write-Host ""

    Show-Status

    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  1. Limit bandwidth (test speed, apply 50% limit)"
    Write-Host "  2. Remove bandwidth limit"
    Write-Host "  3. Check current status"
    Write-Host "  4. Exit"
    Write-Host ""

    $choice = Read-Host "Enter choice (1-4)"

    switch ($choice) {
        "1" {
            $script:Limit = $true
        }
        "2" {
            $script:Unlimit = $true
        }
        "3" {
            Show-Status
            Show-Menu
        }
        "4" {
            exit 0
        }
        default {
            Write-Warn "Invalid choice"
            Show-Menu
        }
    }
}

# Banner
function Show-Banner {
    Write-Host @"

   ____  _ _                         ____                  _          _     _   _
  / __ \| | |                       |  _ \                | |        (_)   | | | |
 | |  | | | | __ _ _ __ ___   __ _  | |_) | __ _ _ __   __| |_      ___  __| | | |__
 | |  | | | |/ _` | '_ ` _ \ / _` | |  _ < / _` | '_ \ / _` \ \ /\ / / |/ _` | | '_ \
 | |__| | | | (_| | | | | | | (_| | | |_) | (_| | | | | (_| |\ V  V /| | (_| | | | | |
  \____/|_|_|\__,_|_| |_| |_|\__,_| |____/ \__,_|_| |_|\__,_| \_/\_/ |_|\__,_| |_| |_|

                          Bandwidth Limiter (Requires Admin)

"@ -ForegroundColor Cyan
}

# Main
function Main {
    Show-Banner

    # Check admin
    if (-not (Test-Admin)) {
        Write-Err "This script requires Administrator privileges!"
        Write-Host ""
        Write-Host "Please right-click and 'Run as Administrator'" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    Write-Success "Running with Administrator privileges"

    # If no flags, show interactive menu
    if (-not $Limit -and -not $Unlimit) {
        Show-Menu
    }

    # Handle Unlimit
    if ($Unlimit) {
        Remove-BandwidthLimit
        exit 0
    }

    # Handle Limit
    if ($Limit) {
        # Get speed
        if ($SkipSpeedTest) {
            $speed = $SpeedMbps
            Write-Info "Using manual speed: ${speed} Mbps"
        } else {
            $speed = Test-DownloadSpeed
            Write-Success "Measured speed: ${speed} Mbps"
        }

        # Calculate limit
        $limitSpeed = [math]::Round($speed * ($Percent / 100), 2)
        Write-Info "Limiting to ${Percent}% = ${limitSpeed} Mbps"

        # Apply limit
        $ollamaPath = Get-OllamaPath
        if ($ollamaPath) {
            Write-Info "Found Ollama: $ollamaPath"
        } else {
            Write-Warn "Ollama not found in PATH, using executable name only"
        }

        Set-BandwidthLimit -ThrottleRateMbps $limitSpeed -AppPath $ollamaPath
    }
}

# Run
Main
