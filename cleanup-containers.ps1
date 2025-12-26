<#
.SYNOPSIS
    Stop and remove Ollama stack containers

.DESCRIPTION
    Removes Open WebUI, Perplexica, and SearXNG containers.
    Optionally removes associated volumes (data).

.PARAMETER DeleteVolumes
    Also delete volumes (persistent data). Will prompt if not specified.

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\cleanup-containers.ps1
    # Interactive - asks what to delete

.EXAMPLE
    .\cleanup-containers.ps1 -DeleteVolumes
    # Remove containers AND volumes

.EXAMPLE
    .\cleanup-containers.ps1 -Force
    # Remove containers only, no prompts
#>

param(
    [switch]$DeleteVolumes,
    [switch]$Force
)

# Output helpers
function Write-Info { param($msg) Write-Host "  [INFO] " -NoNewline -ForegroundColor Cyan; Write-Host $msg }
function Write-Success { param($msg) Write-Host "  [OK]   " -NoNewline -ForegroundColor Green; Write-Host $msg }
function Write-Warn { param($msg) Write-Host "  [WARN] " -NoNewline -ForegroundColor Yellow; Write-Host $msg }
function Write-Err { param($msg) Write-Host "  [ERR]  " -NoNewline -ForegroundColor Red; Write-Host $msg }

# Container runtime detection
$script:ContainerRuntime = $null

function Find-ContainerRuntime {
    # Check Docker first
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($docker) {
        $info = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            $script:ContainerRuntime = "docker"
            return $true
        }
    }

    # Check Podman
    $podman = Get-Command podman -ErrorAction SilentlyContinue
    if ($podman) {
        $info = podman info 2>&1
        if ($LASTEXITCODE -eq 0) {
            $script:ContainerRuntime = "podman"
            return $true
        }
    }

    Write-Err "No container runtime found (Docker or Podman)"
    return $false
}

# Our containers
$Containers = @(
    "open-webui",
    "perplexica-frontend",
    "perplexica-backend",
    "searxng"
)

# Associated volumes
$Volumes = @(
    "open-webui"
)

function Get-ContainerStatus {
    param([string]$Name)

    $exists = & $script:ContainerRuntime ps -a --filter "name=^${Name}$" --format "{{.Names}}" 2>$null
    if ($exists -eq $Name) {
        $status = & $script:ContainerRuntime inspect $Name --format "{{.State.Status}}" 2>$null
        return @{ Exists = $true; Status = $status }
    }
    return @{ Exists = $false; Status = $null }
}

function Show-Status {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Ollama Stack Cleanup" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Containers:" -ForegroundColor Yellow

    $found = $false
    foreach ($name in $Containers) {
        $info = Get-ContainerStatus -Name $name
        if ($info.Exists) {
            $found = $true
            $statusColor = if ($info.Status -eq "running") { "Green" } else { "Gray" }
            Write-Host "  - $name " -NoNewline
            Write-Host "($($info.Status))" -ForegroundColor $statusColor
        }
    }

    if (-not $found) {
        Write-Host "  (none found)" -ForegroundColor Gray
    }

    Write-Host ""
    return $found
}

function Remove-Containers {
    param([bool]$IncludeVolumes)

    Write-Host ""
    Write-Info "Stopping containers..."

    foreach ($name in $Containers) {
        $info = Get-ContainerStatus -Name $name
        if ($info.Exists) {
            if ($info.Status -eq "running") {
                & $script:ContainerRuntime stop $name 2>&1 | Out-Null
            }

            if ($IncludeVolumes) {
                & $script:ContainerRuntime rm -v $name 2>&1 | Out-Null
            } else {
                & $script:ContainerRuntime rm $name 2>&1 | Out-Null
            }

            Write-Success "Removed $name"
        }
    }

    # Remove named volumes if requested
    if ($IncludeVolumes) {
        Write-Host ""
        Write-Info "Removing volumes..."
        foreach ($vol in $Volumes) {
            $exists = & $script:ContainerRuntime volume ls --filter "name=^${vol}$" --format "{{.Name}}" 2>$null
            if ($exists) {
                & $script:ContainerRuntime volume rm $vol 2>&1 | Out-Null
                Write-Success "Removed volume: $vol"
            }
        }

        # Remove Perplexica network if exists
        $networks = @("perplexica-network", "ollama-rtx-setup_perplexica-network")
        foreach ($net in $networks) {
            $exists = & $script:ContainerRuntime network ls --filter "name=$net" --format "{{.Name}}" 2>$null
            if ($exists) {
                & $script:ContainerRuntime network rm $net 2>&1 | Out-Null
                Write-Success "Removed network: $net"
            }
        }
    }
}

# Main
if (-not (Find-ContainerRuntime)) {
    exit 1
}

Write-Info "Using $($script:ContainerRuntime)"

$hasContainers = Show-Status

if (-not $hasContainers) {
    Write-Host "No containers to clean up." -ForegroundColor Green
    Write-Host ""
    exit 0
}

# Determine if we should delete volumes
$removeVolumes = $DeleteVolumes

if (-not $Force -and -not $DeleteVolumes) {
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  1. Remove containers only (keep data)" -ForegroundColor White
    Write-Host "  2. Remove containers AND volumes (delete all data)" -ForegroundColor White
    Write-Host "  3. Cancel" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Choose [1/2/3]"

    switch ($choice) {
        "1" { $removeVolumes = $false }
        "2" { $removeVolumes = $true }
        default {
            Write-Host "Cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
}

if (-not $Force) {
    $confirmMsg = if ($removeVolumes) {
        "Remove all containers AND volumes? This will DELETE ALL DATA. (y/N)"
    } else {
        "Remove all containers? (y/N)"
    }

    $confirm = Read-Host $confirmMsg
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Remove-Containers -IncludeVolumes $removeVolumes

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Cleanup complete!" -ForegroundColor Green
if ($removeVolumes) {
    Write-Host "  Containers and volumes removed" -ForegroundColor Gray
} else {
    Write-Host "  Containers removed (volumes preserved)" -ForegroundColor Gray
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To reinstall:" -ForegroundColor Yellow
Write-Host "  .\setup-ollama-websearch.ps1 -Setup OpenWebUI"
Write-Host "  .\setup-ollama-websearch.ps1 -Setup Perplexica"
Write-Host ""
