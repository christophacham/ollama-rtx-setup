<#
.SYNOPSIS
    Debug and fix Ollama connection issues for Podman containers

.DESCRIPTION
    Diagnoses why containers (Open WebUI, Perplexica) can't connect to Ollama
    when using Podman on Windows/WSL2. Optionally fixes the issue automatically.

.PARAMETER Fix
    Automatically fix the issue by recreating the container with correct settings

.PARAMETER Container
    Container name to debug (default: open-webui)

.EXAMPLE
    .\debug-ollama-connection.ps1
    # Diagnose only - no changes made

.EXAMPLE
    .\debug-ollama-connection.ps1 -Fix
    # Diagnose and fix automatically

.EXAMPLE
    .\debug-ollama-connection.ps1 -Container perplexica-backend -Fix
    # Fix a different container
#>

param(
    [switch]$Fix,
    [string]$Container = "open-webui"
)

# Output helpers
function Write-Pass { param($msg) Write-Host "  [PASS] " -NoNewline -ForegroundColor Green; Write-Host $msg }
function Write-Fail { param($msg) Write-Host "  [FAIL] " -NoNewline -ForegroundColor Red; Write-Host $msg }
function Write-Info { param($msg) Write-Host "  [INFO] " -NoNewline -ForegroundColor Cyan; Write-Host $msg }
function Write-Warn { param($msg) Write-Host "  [WARN] " -NoNewline -ForegroundColor Yellow; Write-Host $msg }
function Write-Section { param($msg) Write-Host "`n[$msg]" -ForegroundColor Magenta }

function Show-ContainerLogs {
    param([string]$ContainerName, [int]$Lines = 15)
    Write-Host ""
    Write-Host "  --- Recent logs from $ContainerName ---" -ForegroundColor Yellow
    podman logs --tail $Lines $ContainerName 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    Write-Host "  --- End of logs ---" -ForegroundColor Yellow
}

# State tracking
$script:Issues = @()
$script:GatewayIP = $null
$script:CurrentUrl = $null
$script:CorrectUrl = $null

function Show-Banner {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Ollama Connection Debugger" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Test-OllamaHost {
    Write-Section "Phase 1: Host Diagnosis"

    # Check Ollama on host
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 5 -ErrorAction Stop
        $modelCount = $response.models.Count
        Write-Pass "Ollama running on host ($modelCount models)"
        return $true
    } catch {
        Write-Fail "Ollama not running on host"
        Write-Info "Start Ollama with: ollama serve"
        $script:Issues += "Ollama not running"
        return $false
    }
}

function Test-Container {
    Write-Section "Phase 2: Container Diagnosis"

    # Check if container exists
    $exists = podman ps -a --filter "name=$Container" --format "{{.Names}}" 2>&1
    if ($exists -ne $Container) {
        Write-Fail "Container '$Container' does not exist"
        $script:Issues += "Container not found"
        return $false
    }

    # Check if running
    $running = podman ps --filter "name=$Container" --format "{{.Names}}" 2>&1
    if ($running -eq $Container) {
        Write-Pass "Container '$Container' is running"
    } else {
        Write-Warn "Container '$Container' exists but not running"
        Write-Info "Starting container..."
        podman start $Container 2>&1 | Out-Null
    }

    # Check restart count (detect restart loops)
    $restarts = podman inspect $Container --format "{{.RestartCount}}" 2>&1
    if ($restarts -and [int]$restarts -gt 3) {
        Write-Fail "Container has restarted $restarts times - possible restart loop"
        $script:Issues += "Restart loop detected"
        Show-ContainerLogs -ContainerName $Container
    } elseif ($restarts -and [int]$restarts -gt 0) {
        Write-Warn "Container has restarted $restarts time(s)"
    }

    # Check health status if available
    $health = podman inspect $Container --format "{{.State.Health.Status}}" 2>&1
    if ($health -and $health -ne "<no value>" -and $health -ne "") {
        if ($health -eq "unhealthy") {
            Write-Fail "Container health check: $health"
            $script:Issues += "Container unhealthy"
            Show-ContainerLogs -ContainerName $Container
        } elseif ($health -eq "healthy") {
            Write-Pass "Container health check: $health"
        } else {
            Write-Info "Container health check: $health"
        }
    }

    # Get current OLLAMA_BASE_URL
    $envVars = podman inspect $Container --format '{{range .Config.Env}}{{println .}}{{end}}' 2>&1
    $ollamaUrl = $envVars | Select-String "OLLAMA_BASE_URL=" | ForEach-Object { $_ -replace 'OLLAMA_BASE_URL=', '' }

    if ($ollamaUrl) {
        $script:CurrentUrl = $ollamaUrl.Trim()
        Write-Info "Current OLLAMA_BASE_URL: $($script:CurrentUrl)"
    } else {
        Write-Warn "No OLLAMA_BASE_URL configured"
        $script:CurrentUrl = "http://host.docker.internal:11434"
    }

    # Check host resolution
    $hostResolution = podman exec $Container getent hosts host.docker.internal 2>&1
    if ($hostResolution -match "169\.254") {
        Write-Warn "host.docker.internal resolves to 169.254.x.x (link-local, won't work)"
        $script:Issues += "Bad host resolution"
    }

    return $true
}

function Test-ContainerConnectivity {
    Write-Section "Phase 3: Connectivity Test"

    # Extract host from current URL
    $urlHost = $script:CurrentUrl -replace 'http://', '' -replace ':11434.*', ''

    # Test connectivity from inside container
    Write-Info "Testing connection to: $($script:CurrentUrl)"

    $testScript = "import urllib.request; urllib.request.urlopen('$($script:CurrentUrl)/api/tags', timeout=5)"
    $result = podman exec $Container python3 -c $testScript 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Pass "Container can reach Ollama via configured URL"
        return $true
    } else {
        Write-Fail "Container CANNOT reach Ollama via configured URL"
        $script:Issues += "Connection failed"
        return $false
    }
}

function Find-GatewayIP {
    Write-Section "Phase 4: Gateway Discovery"

    # Get default Podman machine
    $machines = podman system connection list --format "{{.Name}}" 2>&1
    if (-not $machines) {
        Write-Fail "No Podman machines found"
        return $false
    }

    $defaultMachine = $machines | Select-Object -First 1
    Write-Info "Using Podman machine: $defaultMachine"

    # Get gateway IP
    $routeOutput = podman machine ssh $defaultMachine 'ip route show default' 2>&1

    if ($routeOutput -match 'via (\d+\.\d+\.\d+\.\d+)') {
        $script:GatewayIP = $Matches[1]
        Write-Pass "Gateway IP found: $($script:GatewayIP)"

        # Test if Ollama is reachable via gateway
        Write-Info "Testing Ollama via gateway..."
        $gatewayTest = podman machine ssh $defaultMachine "curl -s --connect-timeout 3 http://$($script:GatewayIP):11434/api/tags" 2>&1

        if ($gatewayTest -match '"models"') {
            Write-Pass "Ollama reachable via gateway IP"
            $script:CorrectUrl = "http://$($script:GatewayIP):11434"
            return $true
        } else {
            Write-Fail "Ollama not reachable via gateway"
            Write-Info "Check Windows Firewall settings"
            return $false
        }
    } else {
        Write-Fail "Could not determine gateway IP"
        Write-Info "Route output: $routeOutput"
        return $false
    }
}

function Show-Analysis {
    Write-Section "Phase 5: Analysis"

    if ($script:Issues.Count -eq 0) {
        Write-Pass "No issues found! Connection is working."
        return $false  # No fix needed
    }

    Write-Host ""
    Write-Host "  Problem Detected:" -ForegroundColor Yellow
    Write-Host "    Container is using: $($script:CurrentUrl)" -ForegroundColor Yellow

    if ($script:CurrentUrl -match "host\.docker\.internal") {
        Write-Host "    This resolves to 169.254.1.2 which doesn't route to Windows" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  Solution:" -ForegroundColor Green
    Write-Host "    Use gateway IP: $($script:CorrectUrl)" -ForegroundColor Green

    return $true  # Fix needed
}

function Invoke-Fix {
    Write-Section "Phase 6: Applying Fix"

    if (-not $script:CorrectUrl) {
        Write-Fail "Cannot fix: correct URL not determined"
        return $false
    }

    # Get current container info for recreation
    $image = podman inspect $Container --format "{{.Config.Image}}" 2>&1
    $ports = podman inspect $Container --format '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}}{{end}}' 2>&1

    Write-Info "Current image: $image"

    # Confirm with user
    Write-Host ""
    Write-Host "  This will:" -ForegroundColor Yellow
    Write-Host "    1. Stop container '$Container'"
    Write-Host "    2. Remove container '$Container' (data volume preserved)"
    Write-Host "    3. Recreate with OLLAMA_BASE_URL=$($script:CorrectUrl)"
    Write-Host ""

    $confirm = Read-Host "  Proceed? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Info "Aborted by user"
        return $false
    }

    # Stop and remove
    Write-Info "Stopping container..."
    podman stop $Container 2>&1 | Out-Null

    Write-Info "Removing container..."
    podman rm $Container 2>&1 | Out-Null

    # Recreate based on container type
    Write-Info "Recreating container..."

    if ($Container -eq "open-webui") {
        $result = podman run -d `
            -p 3000:8080 `
            -v open-webui:/app/backend/data `
            -e "OLLAMA_BASE_URL=$($script:CorrectUrl)" `
            --name open-webui `
            --restart always `
            $image 2>&1
    } else {
        # Generic container recreation
        $result = podman run -d `
            -e "OLLAMA_BASE_URL=$($script:CorrectUrl)" `
            --name $Container `
            --restart always `
            $image 2>&1
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Pass "Container recreated successfully"

        # Wait and verify
        Write-Info "Waiting for container to start..."
        Start-Sleep -Seconds 5

        # Verify connectivity
        $testScript = "import urllib.request; urllib.request.urlopen('$($script:CorrectUrl)/api/tags', timeout=5)"
        $verify = podman exec $Container python3 -c $testScript 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Pass "Connectivity verified!"
            return $true
        } else {
            Write-Fail "Connectivity still failing after fix"
            return $false
        }
    } else {
        Write-Fail "Failed to recreate container: $result"
        return $false
    }
}

function Show-Summary {
    param([bool]$Success)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan

    if ($Success) {
        Write-Host "  Fix complete!" -ForegroundColor Green
        Write-Host "  Open WebUI: http://localhost:3000" -ForegroundColor Green
    } elseif ($script:Issues.Count -eq 0) {
        Write-Host "  No issues found - connection working!" -ForegroundColor Green
    } else {
        Write-Host "  Issues detected but not fixed" -ForegroundColor Yellow
        Write-Host "  Run with -Fix to apply solution" -ForegroundColor Yellow
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Main execution
Show-Banner

$ollamaOk = Test-OllamaHost
if (-not $ollamaOk) {
    Show-Summary -Success $false
    exit 1
}

$containerOk = Test-Container
if (-not $containerOk) {
    Show-Summary -Success $false
    exit 1
}

$connectOk = Test-ContainerConnectivity

if (-not $connectOk) {
    $gatewayOk = Find-GatewayIP

    if ($gatewayOk) {
        $needsFix = Show-Analysis

        if ($needsFix -and $Fix) {
            $fixSuccess = Invoke-Fix
            Show-Summary -Success $fixSuccess
            exit $(if ($fixSuccess) { 0 } else { 1 })
        }
    }
}

Show-Summary -Success $connectOk
exit $(if ($connectOk) { 0 } else { 1 })
