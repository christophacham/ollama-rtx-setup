<#
.SYNOPSIS
    Sync container images to your own GHCR registry

.DESCRIPTION
    Checks for upstream image updates and mirrors them to ghcr.io/christophacham/ollama-rtx-setup.
    Tracks versions via container-versions.json.

.PARAMETER Sync
    Actually sync images (default is check-only)

.PARAMETER Force
    Sync all images regardless of status

.PARAMETER Image
    Sync only a specific image (e.g., "open-webui:cuda")

.EXAMPLE
    .\sync-container-images.ps1
    # Check status only

.EXAMPLE
    .\sync-container-images.ps1 -Sync
    # Sync changed images

.EXAMPLE
    .\sync-container-images.ps1 -Force
    # Sync all images
#>

param(
    [switch]$Sync,
    [switch]$Force,
    [string]$Image
)

$ErrorActionPreference = "Stop"
$script:VersionFile = Join-Path $PSScriptRoot "container-versions.json"
$script:ContainerEngine = $null
$script:UpdatesAvailable = @()

# Output helpers
function Write-Status { param($status, $color, $msg) Write-Host "  [$status] " -NoNewline -ForegroundColor $color; Write-Host $msg }
function Write-Current { param($msg) Write-Status "CURRENT" "Green" $msg }
function Write-Update { param($msg) Write-Status "UPDATE" "Yellow" $msg }
function Write-New { param($msg) Write-Status "NEW" "Cyan" $msg }
function Write-Error { param($msg) Write-Status "ERROR" "Red" $msg }
function Write-Synced { param($msg) Write-Status "SYNCED" "Green" $msg }
function Write-Section { param($msg) Write-Host "`n[$msg]" -ForegroundColor Magenta }

function Show-Banner {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Container Image Sync" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Find-ContainerEngine {
    # Prefer docker in CI (GitHub Actions), podman locally
    if ($env:CI -eq "true" -or $env:GITHUB_ACTIONS -eq "true") {
        if (Get-Command "docker" -ErrorAction SilentlyContinue) {
            $script:ContainerEngine = "docker"
            return $true
        }
    }

    if (Get-Command "podman" -ErrorAction SilentlyContinue) {
        $info = podman info 2>&1
        if ($LASTEXITCODE -eq 0) {
            $script:ContainerEngine = "podman"
            return $true
        }
    }

    if (Get-Command "docker" -ErrorAction SilentlyContinue) {
        $info = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            $script:ContainerEngine = "docker"
            return $true
        }
    }

    return $false
}

function Test-RegistryAuth {
    param([string]$Registry)

    Write-Section "Authentication Check"

    # Try to inspect a known public image to verify connection
    $testResult = & $script:ContainerEngine manifest inspect "ghcr.io/open-webui/open-webui:cuda" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Cannot reach ghcr.io - check network connectivity"
        return $false
    }

    Write-Host "  [OK] Container engine: $($script:ContainerEngine)" -ForegroundColor Green

    if ($Sync -or $Force) {
        # In CI (GitHub Actions), login happens before script runs via workflow step
        if ($env:CI -eq "true" -or $env:GITHUB_ACTIONS -eq "true") {
            Write-Host "  [OK] Running in GitHub Actions (auth via workflow)" -ForegroundColor Green
            return $true
        }

        # For local runs, verify login status
        $loginCheck = & $script:ContainerEngine login ghcr.io --get-login 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Not logged in to ghcr.io"
            Write-Host "  Run: $($script:ContainerEngine) login ghcr.io -u YOUR_USERNAME" -ForegroundColor Yellow
            return $false
        }
        Write-Host "  [OK] Authenticated to ghcr.io as: $loginCheck" -ForegroundColor Green
    }

    return $true
}

function Get-ImageDigest {
    param([string]$ImageRef)

    # Method 1: Try docker/podman pull + inspect (most reliable)
    # Pull quietly to get the image, then inspect for digest
    $pullOutput = & $script:ContainerEngine pull $ImageRef 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Get digest from inspect
        $digestOutput = & $script:ContainerEngine inspect $ImageRef --format "{{index .RepoDigests 0}}" 2>&1
        if ($LASTEXITCODE -eq 0 -and $digestOutput -match '@(sha256:[a-f0-9]+)') {
            return $Matches[1]
        }
        # Fallback: get image ID as pseudo-digest
        $idOutput = & $script:ContainerEngine inspect $ImageRef --format "{{.Id}}" 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $idOutput.Trim()
        }
    }

    # Method 2: Try manifest inspect (works for some registries)
    $output = & $script:ContainerEngine manifest inspect $ImageRef 2>&1
    if ($LASTEXITCODE -eq 0) {
        try {
            $manifest = $output | ConvertFrom-Json
            if ($manifest.digest) {
                return $manifest.digest
            }
        } catch {}
    }

    return $null
}

function Read-VersionFile {
    if (-not (Test-Path $script:VersionFile)) {
        Write-Error "Version file not found: $($script:VersionFile)"
        exit 1
    }

    return Get-Content $script:VersionFile -Raw | ConvertFrom-Json
}

function Save-VersionFile {
    param($Data)

    # Atomic write: write to temp, then rename
    $tempFile = "$($script:VersionFile).tmp"
    $Data | ConvertTo-Json -Depth 10 | Set-Content $tempFile -Encoding UTF8
    Move-Item $tempFile $script:VersionFile -Force
}

function Check-Images {
    Write-Section "Checking Images"

    $versions = Read-VersionFile
    $registry = $versions.registry

    foreach ($imageName in $versions.images.PSObject.Properties.Name) {
        # Filter if specific image requested
        if ($Image -and $imageName -ne $Image) {
            continue
        }

        $imageInfo = $versions.images.$imageName
        $upstream = $imageInfo.upstream
        $localRef = "$registry/$imageName"

        Write-Host "`n  $imageName" -ForegroundColor White
        Write-Host "    Upstream: $upstream" -ForegroundColor Gray

        # Get upstream digest
        $upstreamDigest = Get-ImageDigest $upstream
        if (-not $upstreamDigest) {
            Write-Error "    Cannot fetch upstream digest"
            continue
        }
        Write-Host "    Upstream digest: $($upstreamDigest.Substring(0, 20))..." -ForegroundColor Gray

        # Get local digest (if exists)
        $localDigest = Get-ImageDigest $localRef

        # Compare
        if (-not $localDigest) {
            Write-New "    Not yet mirrored"
            $script:UpdatesAvailable += @{
                Name = $imageName
                Upstream = $upstream
                Local = $localRef
                UpstreamDigest = $upstreamDigest
                Reason = "new"
            }
        } elseif ($upstreamDigest -ne $imageInfo.upstream_digest) {
            Write-Update "    Upstream changed"
            $script:UpdatesAvailable += @{
                Name = $imageName
                Upstream = $upstream
                Local = $localRef
                UpstreamDigest = $upstreamDigest
                Reason = "update"
            }
        } elseif ($Force) {
            Write-Update "    Forced sync"
            $script:UpdatesAvailable += @{
                Name = $imageName
                Upstream = $upstream
                Local = $localRef
                UpstreamDigest = $upstreamDigest
                Reason = "force"
            }
        } else {
            Write-Current "    Up to date"
        }
    }

    # Update last check time
    $versions.last_check = (Get-Date).ToString("o")
    Save-VersionFile $versions
}

function Sync-Images {
    if ($script:UpdatesAvailable.Count -eq 0) {
        Write-Host "`n  No updates to sync." -ForegroundColor Green
        return
    }

    Write-Section "Syncing Images"

    $versions = Read-VersionFile
    $synced = 0

    foreach ($update in $script:UpdatesAvailable) {
        Write-Host "`n  Syncing: $($update.Name)" -ForegroundColor Yellow

        # Pull upstream
        Write-Host "    Pulling from upstream..." -ForegroundColor Gray
        & $script:ContainerEngine pull $update.Upstream 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "    Failed to pull upstream"
            continue
        }

        # Tag for local registry
        Write-Host "    Tagging for local registry..." -ForegroundColor Gray
        & $script:ContainerEngine tag $update.Upstream $update.Local 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "    Failed to tag image"
            continue
        }

        # Push to local registry
        Write-Host "    Pushing to registry..." -ForegroundColor Gray
        & $script:ContainerEngine push $update.Local 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "    Failed to push image"
            continue
        }

        # Update version file (only after successful push)
        $versions.images.($update.Name).upstream_digest = $update.UpstreamDigest
        $versions.images.($update.Name).local_digest = $update.UpstreamDigest
        $versions.images.($update.Name).synced_at = (Get-Date).ToString("o")
        $versions.images.($update.Name).status = "synced"

        Write-Synced "    Successfully synced"
        $synced++
    }

    # Save updated versions
    Save-VersionFile $versions

    Write-Host "`n  Synced $synced of $($script:UpdatesAvailable.Count) images" -ForegroundColor Cyan
}

function Show-Summary {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan

    if ($script:UpdatesAvailable.Count -eq 0) {
        Write-Host "  All images up to date" -ForegroundColor Green
    } elseif (-not $Sync -and -not $Force) {
        Write-Host "  $($script:UpdatesAvailable.Count) update(s) available" -ForegroundColor Yellow
        Write-Host "  Run with -Sync to apply" -ForegroundColor Yellow
    } else {
        Write-Host "  Sync complete" -ForegroundColor Green
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Main
Show-Banner

if (-not (Find-ContainerEngine)) {
    Write-Error "No container engine found (docker/podman)"
    exit 1
}

if (-not (Test-RegistryAuth)) {
    exit 1
}

Check-Images

if ($Sync -or $Force) {
    Sync-Images
}

Show-Summary
