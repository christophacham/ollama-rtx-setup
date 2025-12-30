<#
.SYNOPSIS
    Syncs ollama-rtx-setup config files to PAL MCP Server.

.DESCRIPTION
    This script backs up PAL's existing configs and replaces them with the
    curated versions from ollama-rtx-setup. Handles both custom_models.json
    (local Ollama) and openrouter_models.json (cloud models).

.PARAMETER PalPath
    Path to PAL MCP Server root. Auto-detects common locations.

.PARAMETER ConfigsOnly
    Only sync config files, skip validation checks.

.PARAMETER List
    Show current status without making changes.

.PARAMETER NoBackup
    Skip creating backups (not recommended).

.EXAMPLE
    .\sync-pal-configs.ps1
    # Auto-detect PAL location, backup, and sync

.EXAMPLE
    .\sync-pal-configs.ps1 -List
    # Show what would be synced without making changes

.EXAMPLE
    .\sync-pal-configs.ps1 -PalPath "C:\code\pal-mcp-server"
    # Specify PAL location explicitly
#>

[CmdletBinding()]
param(
    [string]$PalPath,
    [switch]$ConfigsOnly,
    [switch]$List,
    [switch]$NoBackup
)

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot

# Colors
function Write-Status { param($msg) Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline; Write-Host $msg }
function Write-Success { param($msg) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Warn { param($msg) Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Err { param($msg) Write-Host "[ERR] " -ForegroundColor Red -NoNewline; Write-Host $msg }

# Config files to sync
$ConfigFiles = @(
    @{ Name = "custom_models.json"; Description = "Local Ollama models" }
    @{ Name = "openrouter_models.json"; Description = "OpenRouter cloud models" }
)

# Find PAL MCP Server
function Find-PalPath {
    $searchPaths = @(
        "$ScriptRoot\..\pal-mcp-server",
        "$env:USERPROFILE\code\pal-mcp-server",
        "C:\Users\Egusto\code\pal-mcp-server",
        "$env:APPDATA\pal-mcp-server"
    )

    foreach ($path in $searchPaths) {
        $resolved = $null
        try {
            if (Test-Path $path) {
                $resolved = (Resolve-Path $path).Path
                # Verify it's actually PAL by checking for conf folder
                if (Test-Path "$resolved\conf") {
                    return $resolved
                }
            }
        } catch {
            continue
        }
    }

    return $null
}

# Compare two JSON files
function Compare-JsonFiles {
    param(
        [string]$SourcePath,
        [string]$TargetPath
    )

    if (-not (Test-Path $SourcePath)) {
        return @{ Status = "missing_source"; Message = "Source file not found" }
    }

    if (-not (Test-Path $TargetPath)) {
        return @{ Status = "missing_target"; Message = "Target file not found (will create)" }
    }

    $sourceHash = (Get-FileHash $SourcePath -Algorithm MD5).Hash
    $targetHash = (Get-FileHash $TargetPath -Algorithm MD5).Hash

    if ($sourceHash -eq $targetHash) {
        return @{ Status = "identical"; Message = "Files are identical" }
    }

    # Count models in each
    try {
        $sourceJson = Get-Content $SourcePath -Raw | ConvertFrom-Json
        $targetJson = Get-Content $TargetPath -Raw | ConvertFrom-Json

        $sourceCount = if ($sourceJson.models) { $sourceJson.models.Count } else { 0 }
        $targetCount = if ($targetJson.models) { $targetJson.models.Count } else { 0 }

        return @{
            Status = "different"
            Message = "Source: $sourceCount models, Target: $targetCount models"
            SourceCount = $sourceCount
            TargetCount = $targetCount
        }
    } catch {
        return @{ Status = "different"; Message = "Files differ (parse error)" }
    }
}

# Backup a file
function Backup-File {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return $null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$FilePath.backup.$timestamp"
    Copy-Item $FilePath $backupPath
    return $backupPath
}

# Sync a config file
function Sync-ConfigFile {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [switch]$SkipBackup
    )

    if (-not (Test-Path $SourcePath)) {
        Write-Err "Source not found: $SourcePath"
        return $false
    }

    # Backup if target exists
    if ((Test-Path $TargetPath) -and -not $SkipBackup) {
        $backupPath = Backup-File $TargetPath
        if ($backupPath) {
            Write-Status "Backed up to: $(Split-Path $backupPath -Leaf)"
        }
    }

    # Copy
    Copy-Item $SourcePath $TargetPath -Force
    return $true
}

# Main
function Main {
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "  PAL MCP Server Config Sync" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""

    # Find PAL
    $palRoot = if ($PalPath) { $PalPath } else { Find-PalPath }

    if (-not $palRoot) {
        Write-Err "Could not find PAL MCP Server"
        Write-Host "  Expected location: ..\pal-mcp-server" -ForegroundColor Gray
        Write-Host "  Specify with: -PalPath <path>" -ForegroundColor Gray
        exit 1
    }

    $palConf = Join-Path $palRoot "conf"

    if (-not (Test-Path $palConf)) {
        Write-Err "PAL conf folder not found: $palConf"
        exit 1
    }

    Write-Status "Source: $ScriptRoot"
    Write-Status "Target: $palRoot"
    Write-Host ""

    # Check each config file
    $syncNeeded = @()

    foreach ($config in $ConfigFiles) {
        $sourcePath = Join-Path $ScriptRoot $config.Name
        $targetPath = Join-Path $palConf $config.Name

        $comparison = Compare-JsonFiles $sourcePath $targetPath

        $statusColor = switch ($comparison.Status) {
            "identical" { "Green" }
            "missing_source" { "Red" }
            "missing_target" { "Yellow" }
            "different" { "Yellow" }
            default { "White" }
        }

        $statusIcon = switch ($comparison.Status) {
            "identical" { "[=]" }
            "missing_source" { "[!]" }
            "missing_target" { "[+]" }
            "different" { "[~]" }
            default { "[?]" }
        }

        Write-Host "$statusIcon " -ForegroundColor $statusColor -NoNewline
        Write-Host "$($config.Name)" -ForegroundColor White -NoNewline
        Write-Host " - $($config.Description)" -ForegroundColor Gray
        Write-Host "    $($comparison.Message)" -ForegroundColor $statusColor

        if ($comparison.Status -ne "identical" -and $comparison.Status -ne "missing_source") {
            $syncNeeded += @{
                Config = $config
                Source = $sourcePath
                Target = $targetPath
                Comparison = $comparison
            }
        }
    }

    Write-Host ""

    # If just listing, stop here
    if ($List) {
        if ($syncNeeded.Count -eq 0) {
            Write-Success "All configs are in sync!"
        } else {
            Write-Warn "$($syncNeeded.Count) config(s) need syncing"
        }
        return
    }

    # Nothing to sync?
    if ($syncNeeded.Count -eq 0) {
        Write-Success "All configs are already in sync!"
        return
    }

    # Confirm
    Write-Host "Will sync $($syncNeeded.Count) config file(s):" -ForegroundColor Yellow
    foreach ($item in $syncNeeded) {
        Write-Host "  -> $($item.Config.Name)" -ForegroundColor Cyan
    }
    Write-Host ""

    $response = Read-Host "Proceed with sync? [y/N]"
    if ($response -notmatch "^[Yy]") {
        Write-Status "Sync cancelled"
        return
    }

    Write-Host ""

    # Sync each file
    $synced = 0
    foreach ($item in $syncNeeded) {
        Write-Status "Syncing $($item.Config.Name)..."

        if (Sync-ConfigFile $item.Source $item.Target -SkipBackup:$NoBackup) {
            Write-Success "Synced $($item.Config.Name)"
            $synced++
        } else {
            Write-Err "Failed to sync $($item.Config.Name)"
        }
    }

    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Green
    Write-Success "Synced $synced config file(s)"
    Write-Host ""
    Write-Host "Restart PAL MCP Server to apply changes:" -ForegroundColor Yellow
    Write-Host "  - Restart Claude Code / Claude Desktop" -ForegroundColor Gray
    Write-Host "=" * 60 -ForegroundColor Green
}

Main
