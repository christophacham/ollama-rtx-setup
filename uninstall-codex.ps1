# Uninstall Codex CLI and Remove All Configuration
# This script completely removes Codex CLI from your system

[CmdletBinding()]
param(
    [switch]$Force  # Skip confirmation prompts
)

Write-Host "Codex CLI Uninstaller" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin (not required but shows warning)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Note: Not running as Administrator. This is fine for Codex uninstall." -ForegroundColor Yellow
    Write-Host ""
}

# Define paths
$codexDir = "$env:USERPROFILE\.codex"
$codexGlobalNpm = "$env:APPDATA\npm\node_modules\@openai\codex-cli"

# Check what exists
$itemsToRemove = @()
$itemsFound = @()

# Check npm package
try {
    $npmList = npm list -g @openai/codex-cli --depth=0 2>$null
    if ($LASTEXITCODE -eq 0) {
        $itemsFound += "NPM package: @openai/codex-cli (global)"
        $itemsToRemove += "npm"
    }
} catch {
    # Package not installed
}

# Check .codex directory
if (Test-Path $codexDir) {
    $size = (Get-ChildItem -Path $codexDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
    $itemsFound += ".codex directory: $codexDir ($([Math]::Round($size, 2)) MB)"
    $itemsToRemove += "config"
}

# Check global npm modules directory
if (Test-Path $codexGlobalNpm) {
    $itemsFound += "NPM module directory: $codexGlobalNpm"
}

# Show what was found
if ($itemsFound.Count -eq 0) {
    Write-Host "Codex CLI is not installed or already removed." -ForegroundColor Green
    Write-Host ""
    Write-Host "Checked locations:" -ForegroundColor Gray
    Write-Host "  - NPM global packages" -ForegroundColor Gray
    Write-Host "  - $codexDir" -ForegroundColor Gray
    exit 0
}

Write-Host "Found the following Codex CLI components:" -ForegroundColor Yellow
foreach ($item in $itemsFound) {
    Write-Host "  - $item" -ForegroundColor White
}
Write-Host ""

# Confirm removal
if (-not $Force) {
    $confirm = Read-Host "Remove all Codex CLI components? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Uninstall cancelled." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
}

# Uninstall npm package
if ($itemsToRemove -contains "npm") {
    Write-Host "[1/2] Uninstalling npm package..." -ForegroundColor Cyan
    try {
        npm uninstall -g @openai/codex-cli
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ NPM package uninstalled" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to uninstall NPM package" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ✗ Error uninstalling NPM package: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Remove .codex directory
if ($itemsToRemove -contains "config") {
    Write-Host "[2/2] Removing configuration directory..." -ForegroundColor Cyan
    try {
        # Show what's being removed
        Write-Host "  Removing: $codexDir" -ForegroundColor Gray

        # Remove directory
        Remove-Item -Path $codexDir -Recurse -Force -ErrorAction Stop

        if (-not (Test-Path $codexDir)) {
            Write-Host "  ✓ Configuration directory removed" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Directory still exists" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ✗ Error removing directory: $_" -ForegroundColor Red
        Write-Host "  Try manually: Remove-Item '$codexDir' -Recurse -Force" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Final verification
Write-Host "Verification:" -ForegroundColor Cyan

# Check npm
try {
    $npmCheck = npm list -g @openai/codex-cli --depth=0 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✓ NPM package: Not installed" -ForegroundColor Green
    } else {
        Write-Host "  ✗ NPM package: Still installed" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✓ NPM package: Not installed" -ForegroundColor Green
}

# Check directory
if (-not (Test-Path $codexDir)) {
    Write-Host "  ✓ Config directory: Removed" -ForegroundColor Green
} else {
    Write-Host "  ✗ Config directory: Still exists" -ForegroundColor Red
}

# Check command availability
try {
    $codexCmd = Get-Command codex -ErrorAction SilentlyContinue
    if ($null -eq $codexCmd) {
        Write-Host "  ✓ Command 'codex': Not found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Command 'codex': Still available at $($codexCmd.Source)" -ForegroundColor Red
        Write-Host "    (May need to restart terminal)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ✓ Command 'codex': Not found" -ForegroundColor Green
}

Write-Host ""
Write-Host "Uninstall complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Restart your terminal for changes to take effect." -ForegroundColor Yellow
Write-Host ""

# Show what was removed
Write-Host "Removed:" -ForegroundColor Gray
if ($itemsToRemove -contains "npm") {
    Write-Host "  - NPM package @openai/codex-cli" -ForegroundColor Gray
}
if ($itemsToRemove -contains "config") {
    Write-Host "  - Configuration directory and history" -ForegroundColor Gray
}
Write-Host ""
