# Codex Aliases Setup Script
# This script adds convenient aliases for Codex with different Ollama models

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Codex Aliases Setup" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Check if profile exists, create if not
if (!(Test-Path -Path $PROFILE)) {
    Write-Host "PowerShell profile not found. Creating..." -ForegroundColor Yellow
    New-Item -Path $PROFILE -Type File -Force | Out-Null
    Write-Host "✓ Profile created at: $PROFILE" -ForegroundColor Green
} else {
    Write-Host "✓ Profile found at: $PROFILE" -ForegroundColor Green
}

# Backup existing profile
$backupPath = "$PROFILE.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -Path $PROFILE -Destination $backupPath
Write-Host "✓ Backup created at: $backupPath" -ForegroundColor Green
Write-Host ""

# The aliases to add
$aliasesContent = @'

# ============================================
# Codex Aliases (Added by setup script)
# ============================================

# Codex with Qwen2.5 Coder (primary coding)
function codex-code {
    codex --oss -m qwen2.5-coder:32b-5090 $args
}

# Codex with DeepSeek R1 (deep thinking/debugging)
function codex-think {
    codex --oss -m deepseek-r1:32b-5090 $args
}

# Codex with Qwen3 (general purpose)
function codex-general {
    codex --oss -m qwen3:32b-5090 $args
}

# Codex with Devstral (Mistral developer model)
function codex-dev {
    codex --oss -m devstral-small-2:latest-5090 $args
}

# Shorter aliases
Set-Alias -Name cx -Value codex-code
Set-Alias -Name cxt -Value codex-think
Set-Alias -Name cxg -Value codex-general
Set-Alias -Name cxd -Value codex-dev

Write-Host "Codex aliases loaded! Use: cx (code), cxt (think), cxg (general), cxd (dev)" -ForegroundColor Green

'@

# Check if aliases already exist
$profileContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue

if ($profileContent -match "Codex Aliases") {
    Write-Host "⚠ Codex aliases already exist in profile!" -ForegroundColor Yellow
    $response = Read-Host "Do you want to replace them? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Setup cancelled. Your backup is still available at: $backupPath" -ForegroundColor Yellow
        exit
    }
    # Remove old aliases section
    $profileContent = $profileContent -replace '(?s)# ={40,}.*?# Codex Aliases.*?# ={40,}.*?(?=\r?\n\r?\n|$)', ''
}

# Add aliases to profile
Add-Content -Path $PROFILE -Value $aliasesContent
Write-Host "✓ Aliases added to PowerShell profile" -ForegroundColor Green
Write-Host ""

# Reload profile
Write-Host "Reloading PowerShell profile..." -ForegroundColor Cyan
. $PROFILE

Write-Host ""
Write-Host "==================================" -ForegroundColor Green
Write-Host "✓ Setup Complete!" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
Write-Host ""
Write-Host "Available commands:" -ForegroundColor Cyan
Write-Host "  cx           - Codex with Qwen2.5 Coder (primary coding)" -ForegroundColor White
Write-Host "  cxt          - Codex with DeepSeek R1 (deep thinking)" -ForegroundColor White
Write-Host "  cxg          - Codex with Qwen3 (general purpose)" -ForegroundColor White
Write-Host "  cxd          - Codex with Devstral (Mistral dev model)" -ForegroundColor White
Write-Host ""
Write-Host "  codex-code   - Same as 'cx'" -ForegroundColor Gray
Write-Host "  codex-think  - Same as 'cxt'" -ForegroundColor Gray
Write-Host "  codex-general- Same as 'cxg'" -ForegroundColor Gray
Write-Host "  codex-dev    - Same as 'cxd'" -ForegroundColor Gray
Write-Host ""
Write-Host "Try it now: type 'cx' to start coding!" -ForegroundColor Yellow
Write-Host ""
