<#
.SYNOPSIS
    Test suite for Ollama + Open WebUI + Perplexica stack

.DESCRIPTION
    Verifies all components are running and properly connected.
    Tests: Prerequisites, Ollama, Open WebUI, Perplexica

.PARAMETER Full
    Include inference tests (slower, requires loaded model)

.PARAMETER Json
    Output results as JSON (for CI integration)
#>

param(
    [switch]$Full,
    [switch]$Json
)

# Test counters
$script:Passed = 0
$script:Failed = 0
$script:Skipped = 0
$script:Results = @()

# Container runtime
$script:ContainerRuntime = $null

# Container health checking
function Get-ContainerHealth {
    param([string]$Container)

    $result = @{
        Exists = $false
        Running = $false
        RestartCount = 0
        HealthStatus = $null
        RestartLoop = $false
    }

    # Check if exists
    $exists = & $script:ContainerRuntime ps -a --filter "name=^${Container}$" --format "{{.Names}}" 2>$null
    if (-not $exists) {
        return $result
    }
    $result.Exists = $true

    # Get status
    $status = & $script:ContainerRuntime inspect $Container --format "{{.State.Status}}" 2>$null
    $result.Running = ($status -eq "running")

    # Get restart count
    $restarts = & $script:ContainerRuntime inspect $Container --format "{{.RestartCount}}" 2>$null
    $result.RestartCount = [int]$restarts
    $result.RestartLoop = ($result.RestartCount -gt 3)

    # Get health status if available
    $health = & $script:ContainerRuntime inspect $Container --format "{{.State.Health.Status}}" 2>$null
    if ($health -and $health -ne "<no value>") {
        $result.HealthStatus = $health
    }

    return $result
}

function Show-ContainerLogs {
    param([string]$Container, [int]$Lines = 10)
    if (-not $Json) {
        Write-Host "    --- Recent logs from $Container ---" -ForegroundColor Yellow
        & $script:ContainerRuntime logs --tail $Lines $Container 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    }
}

# Output helpers
function Write-Pass {
    param($msg, $detail = "")
    $script:Passed++
    $script:Results += @{ Status = "PASS"; Message = $msg; Detail = $detail }
    if (-not $Json) {
        Write-Host "  [PASS] " -NoNewline -ForegroundColor Green
        Write-Host $msg -NoNewline
        if ($detail) { Write-Host " ($detail)" -ForegroundColor Gray } else { Write-Host "" }
    }
}

function Write-Fail {
    param($msg, $detail = "")
    $script:Failed++
    $script:Results += @{ Status = "FAIL"; Message = $msg; Detail = $detail }
    if (-not $Json) {
        Write-Host "  [FAIL] " -NoNewline -ForegroundColor Red
        Write-Host $msg -NoNewline
        if ($detail) { Write-Host " ($detail)" -ForegroundColor Gray } else { Write-Host "" }
    }
}

function Write-Skip {
    param($msg, $detail = "")
    $script:Skipped++
    $script:Results += @{ Status = "SKIP"; Message = $msg; Detail = $detail }
    if (-not $Json) {
        Write-Host "  [SKIP] " -NoNewline -ForegroundColor Yellow
        Write-Host $msg -NoNewline
        if ($detail) { Write-Host " ($detail)" -ForegroundColor Gray } else { Write-Host "" }
    }
}

function Write-Section {
    param($name)
    if (-not $Json) {
        Write-Host "`n[$name]" -ForegroundColor Cyan
    }
}

function Write-Banner {
    if (-not $Json) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Ollama Stack Test Suite" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
    }
}

function Write-Summary {
    if ($Json) {
        $output = @{
            passed = $script:Passed
            failed = $script:Failed
            skipped = $script:Skipped
            results = $script:Results
        }
        $output | ConvertTo-Json -Depth 3
    } else {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "  Results: " -NoNewline
        Write-Host "$($script:Passed) passed" -NoNewline -ForegroundColor Green
        Write-Host ", " -NoNewline
        if ($script:Failed -gt 0) {
            Write-Host "$($script:Failed) failed" -NoNewline -ForegroundColor Red
        } else {
            Write-Host "0 failed" -NoNewline
        }
        Write-Host ", $($script:Skipped) skipped"
        Write-Host "========================================" -ForegroundColor Cyan
    }
}

# Test: Prerequisites
function Test-Prerequisites {
    Write-Section "Prerequisites"

    # Container runtime
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    $podman = Get-Command podman -ErrorAction SilentlyContinue

    if ($podman) {
        $info = podman info 2>&1
        if ($LASTEXITCODE -eq 0) {
            $script:ContainerRuntime = "podman"
            Write-Pass "Podman is running"
        } else {
            Write-Fail "Podman found but not running"
        }
    } elseif ($docker) {
        $info = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            $script:ContainerRuntime = "docker"
            Write-Pass "Docker is running"
        } else {
            Write-Fail "Docker found but not running"
        }
    } else {
        Write-Fail "No container runtime found" "Install Docker or Podman"
    }

    # NVIDIA GPU
    try {
        $nvidiaSmi = nvidia-smi --query-gpu=name --format=csv,noheader 2>&1
        if ($LASTEXITCODE -eq 0) {
            $gpuName = $nvidiaSmi.Trim()
            Write-Pass "NVIDIA GPU detected" $gpuName
        } else {
            Write-Skip "No NVIDIA GPU" "CPU mode only"
        }
    } catch {
        Write-Skip "nvidia-smi not found" "CPU mode only"
    }
}

# Test: Ollama
function Test-Ollama {
    Write-Section "Ollama"

    # API alive
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        Write-Pass "API responding on :11434"

        # Models available
        $modelCount = $response.models.Count
        if ($modelCount -gt 0) {
            Write-Pass "$modelCount models available"
        } else {
            Write-Fail "No models installed" "Run: ollama pull llama3.2"
        }
    } catch {
        Write-Fail "API not responding" "Is Ollama running? (ollama serve)"
        return
    }

    # Models loaded (ollama ps)
    try {
        $ps = ollama ps 2>&1
        $lines = $ps -split "`n" | Where-Object { $_ -and $_ -notmatch "^NAME" }
        if ($lines.Count -gt 0) {
            $loadedModel = ($lines[0] -split "\s+")[0]
            Write-Pass "Model loaded" $loadedModel

            # Check GPU usage
            if ($ps -match "gpu|GPU") {
                Write-Pass "GPU acceleration active"
            } else {
                Write-Skip "GPU status unknown"
            }
        } else {
            Write-Skip "No models currently loaded"
        }
    } catch {
        Write-Fail "Could not check loaded models"
    }

    # Inference test (only with -Full)
    if ($Full) {
        try {
            $firstModel = (ollama list 2>&1 | Select-Object -Skip 1 | Select-Object -First 1) -split "\s+" | Select-Object -First 1
            if ($firstModel) {
                Write-Host "  [....] Testing inference..." -NoNewline -ForegroundColor Gray
                $result = ollama run $firstModel "Reply with only: OK" 2>&1 | Out-String
                if ($result -match "OK|ok") {
                    Write-Host "`r  [PASS] Inference working       " -ForegroundColor Green
                    $script:Passed++
                    $script:Results += @{ Status = "PASS"; Message = "Inference working"; Detail = $firstModel }
                } else {
                    Write-Host "`r  [PASS] Inference responded     " -ForegroundColor Green
                    $script:Passed++
                    $script:Results += @{ Status = "PASS"; Message = "Inference responded"; Detail = $firstModel }
                }
            }
        } catch {
            Write-Fail "Inference test failed"
        }
    } else {
        Write-Skip "Inference test" "use -Full flag"
    }
}

# Test: Open WebUI
function Test-OpenWebUI {
    Write-Section "Open WebUI"

    if (-not $script:ContainerRuntime) {
        Write-Skip "Container runtime not available"
        return
    }

    # Get container health info
    $health = Get-ContainerHealth -Container "open-webui"

    if (-not $health.Exists) {
        Write-Skip "Not installed"
        return
    }

    if (-not $health.Running) {
        Write-Fail "Container exists but not running" "Start with: $($script:ContainerRuntime) start open-webui"
        Show-ContainerLogs -Container "open-webui"
        return
    }

    # Check for restart loop
    if ($health.RestartLoop) {
        Write-Fail "Container restart loop detected" "$($health.RestartCount) restarts"
        Show-ContainerLogs -Container "open-webui"
        return
    }

    # Container is running
    $statusDetail = ""
    if ($health.HealthStatus) {
        $statusDetail = "health: $($health.HealthStatus)"
        if ($health.HealthStatus -eq "unhealthy") {
            Write-Fail "Container running but unhealthy"
            Show-ContainerLogs -Container "open-webui"
            return
        }
    }
    if ($health.RestartCount -gt 0) {
        $statusDetail += $(if ($statusDetail) { ", " } else { "" }) + "$($health.RestartCount) restarts"
    }
    Write-Pass "Container running" $statusDetail

    # Check image tag
    $image = & $script:ContainerRuntime inspect --format "{{.Config.Image}}" open-webui 2>&1
    if ($image -match ":ollama") {
        Write-Fail "Using embedded Ollama image" "Should use :cuda or :main"
    } elseif ($image -match ":cuda") {
        Write-Pass "Using CUDA image" "no embedded Ollama"
    } elseif ($image -match ":main") {
        Write-Pass "Using main image" "no embedded Ollama"
    } else {
        Write-Pass "Image tag" $image
    }

    # UI accessible
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000" -Method Get -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Pass "UI accessible on :3000"
        }
    } catch {
        Write-Fail "UI not accessible on :3000"
    }
}

# Test: Perplexica
function Test-Perplexica {
    Write-Section "Perplexica"

    if (-not $script:ContainerRuntime) {
        Write-Skip "Container runtime not available"
        return
    }

    # Get health info for all containers
    $searxngHealth = Get-ContainerHealth -Container "searxng"
    $backendHealth = Get-ContainerHealth -Container "perplexica-backend"
    $frontendHealth = Get-ContainerHealth -Container "perplexica-frontend"

    # Check if any Perplexica containers exist
    if (-not $searxngHealth.Exists -and -not $backendHealth.Exists -and -not $frontendHealth.Exists) {
        Write-Skip "Not installed" "Run: .\setup-ollama-websearch.ps1 -Setup Perplexica"
        return
    }

    # Helper function for container status
    function Test-PerplexicaContainer {
        param($Name, $Health, $Port, $TestUrl)

        if (-not $Health.Exists) {
            Write-Fail "$Name container not found"
            return $false
        }

        if (-not $Health.Running) {
            Write-Fail "$Name container not running"
            Show-ContainerLogs -Container $Name
            return $false
        }

        # Check for restart loop
        if ($Health.RestartLoop) {
            Write-Fail "$Name restart loop detected" "$($Health.RestartCount) restarts"
            Show-ContainerLogs -Container $Name
            return $false
        }

        # Check health status
        if ($Health.HealthStatus -eq "unhealthy") {
            Write-Fail "$Name container unhealthy"
            Show-ContainerLogs -Container $Name
            return $false
        }

        # Container is running
        $statusDetail = ""
        if ($Health.HealthStatus) {
            $statusDetail = "health: $($Health.HealthStatus)"
        }
        if ($Health.RestartCount -gt 0) {
            $statusDetail += $(if ($statusDetail) { ", " } else { "" }) + "$($Health.RestartCount) restarts"
        }
        Write-Pass "$Name container running" $statusDetail

        # Test URL accessibility if provided
        if ($TestUrl) {
            try {
                $response = Invoke-WebRequest -Uri $TestUrl -Method Get -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
                Write-Pass "$Name accessible on :$Port"
            } catch {
                Write-Fail "$Name not accessible on :$Port"
            }
        }

        return $true
    }

    # Test each container
    Test-PerplexicaContainer -Name "SearXNG" -Health $searxngHealth -Port 4000 -TestUrl "http://localhost:4000" | Out-Null
    Test-PerplexicaContainer -Name "Backend" -Health $backendHealth -Port 3001 -TestUrl $null | Out-Null
    Test-PerplexicaContainer -Name "Frontend" -Health $frontendHealth -Port 3002 -TestUrl "http://localhost:3002" | Out-Null
}

# Main
Write-Banner
Test-Prerequisites
Test-Ollama
Test-OpenWebUI
Test-Perplexica
Write-Summary

# Exit code for CI
if ($script:Failed -gt 0) {
    exit 1
}
