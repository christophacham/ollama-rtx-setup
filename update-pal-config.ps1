<#
.SYNOPSIS
    Updates PAL MCP Server custom_models.json based on locally installed Ollama models.

.DESCRIPTION
    This script scans your local Ollama models and updates the PAL MCP Server
    configuration to match. It detects -5090 optimized variants and maps them
    to appropriate model capabilities for tools like thinkdeep, consensus, etc.

.PARAMETER PalConfigPath
    Path to PAL MCP Server custom_models.json. Auto-detects common locations.

.PARAMETER List
    Show current PAL config vs installed Ollama models without making changes.

.PARAMETER NoPrompt
    Update without asking for confirmation.

.PARAMETER Prefer5090
    When both base and -5090 variant exist, configure PAL to use the -5090 version.

.EXAMPLE
    .\update-pal-config.ps1
    # Scan and prompt for updates

.EXAMPLE
    .\update-pal-config.ps1 -List
    # Compare installed models vs PAL config

.EXAMPLE
    .\update-pal-config.ps1 -Prefer5090 -NoPrompt
    # Auto-update to prefer -5090 variants
#>

[CmdletBinding()]
param(
    [string]$PalConfigPath,
    [switch]$List,
    [switch]$NoPrompt,
    [switch]$Prefer5090
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Status { param($msg) Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline; Write-Host $msg }
function Write-Success { param($msg) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Warn { param($msg) Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Err { param($msg) Write-Host "[ERR] " -ForegroundColor Red -NoNewline; Write-Host $msg }

# Model capability database - defines attributes for thinkdeep, consensus, etc.
$script:ModelCapabilities = @{
    # Reasoning models (great for thinkdeep, consensus)
    "deepseek-r1" = @{
        Description = "DeepSeek-R1 - Best local reasoning model, approaches O3/Gemini 2.5 Pro"
        IntelligenceScore = 18
        SupportsExtendedThinking = $true
        SupportsJson = $true
        Context = 128000
        MaxOutput = 32768
        Aliases = @("deepseek-r1", "deepseek", "r1", "reasoning", "think")
    }
    "qwen3" = @{
        Description = "Qwen3 - Dual thinking/non-thinking modes, strong reasoning"
        IntelligenceScore = 17
        SupportsExtendedThinking = $true
        SupportsJson = $true
        Context = 131072
        MaxOutput = 32768
        Aliases = @("qwen3", "qwen", "local-qwen")
    }
    "nemotron-3-nano" = @{
        Description = "Nemotron-3 Nano 30B - NVIDIA's efficient reasoning model"
        IntelligenceScore = 16
        SupportsExtendedThinking = $true
        SupportsJson = $true
        Context = 131072
        MaxOutput = 32768
        Aliases = @("nemotron", "nemotron-nano", "nvidia")
    }

    # Coding models (great for codereview, refactor, debug)
    "qwen2.5-coder" = @{
        Description = "Qwen 2.5 Coder - Best local coding model, 92 languages, rivals GPT-4o"
        IntelligenceScore = 18
        SupportsExtendedThinking = $false
        SupportsJson = $true
        Context = 131072
        MaxOutput = 32768
        Aliases = @("qwen-coder", "qwen-code", "coder", "qwen25-coder")
    }
    "qwen3-coder" = @{
        Description = "Qwen3 Coder 30B - Latest coding model with 256K context (MoE)"
        IntelligenceScore = 17
        SupportsExtendedThinking = $true
        SupportsJson = $true
        Context = 262144
        MaxOutput = 32768
        Aliases = @("qwen3-coder", "qwen3-code")
    }
    "devstral-small-2" = @{
        Description = "Devstral Small 2 - 384K context, vision, 65.8% SWE-Bench"
        IntelligenceScore = 17
        SupportsExtendedThinking = $false
        SupportsJson = $true
        SupportsImages = $true
        Context = 393216
        MaxOutput = 32768
        Aliases = @("devstral-small", "devstral2")
    }
    "devstral" = @{
        Description = "Devstral - Agentic coding model, 46.8% SWE-Bench, Apache 2.0"
        IntelligenceScore = 16
        SupportsExtendedThinking = $false
        SupportsJson = $true
        Context = 131072
        MaxOutput = 32768
        Aliases = @("devstral", "mistral-code")
    }
    "NeuralNexusLab/CodeXor:20b" = @{
        Description = "CodeXor 20B - GPT-OSS base, zero-omission, matches o3-mini on coding"
        IntelligenceScore = 17
        SupportsExtendedThinking = $false
        SupportsJson = $true
        SupportsFunctionCalling = $true
        Context = 131072
        MaxOutput = 32768
        Aliases = @("codexor", "codexor-20b", "xor-20b", "zero-omission")
    }
    "NeuralNexusLab/CodeXor:12b" = @{
        Description = "CodeXor 12B - Gemma 3 base with VISION for screenshots/diagrams"
        IntelligenceScore = 16
        SupportsExtendedThinking = $false
        SupportsJson = $true
        SupportsImages = $true
        SupportsFunctionCalling = $true
        Context = 131072
        MaxOutput = 32768
        Aliases = @("codexor-12b", "xor-12b", "codexor-vision", "vision-coder")
    }
    "second_constantine/deepseek-coder-v2:16b" = @{
        Description = "DeepSeek Coder V2 16B - Community fine-tune, 87 languages"
        IntelligenceScore = 15
        SupportsExtendedThinking = $false
        SupportsJson = $true
        Context = 65536
        MaxOutput = 16384
        Aliases = @("deepseek-coder-v2", "dscv2")
    }
    "codellama" = @{
        Description = "CodeLlama 34B - Meta's premier coding model, 20+ languages"
        IntelligenceScore = 15
        SupportsExtendedThinking = $false
        SupportsJson = $false
        Context = 16384
        MaxOutput = 8192
        Aliases = @("codellama", "code-llama", "llama-code")
    }
    "deepseek-coder" = @{
        Description = "DeepSeek Coder 33B - Strong coding model, 87 languages"
        IntelligenceScore = 15
        SupportsExtendedThinking = $false
        SupportsJson = $true
        Context = 16384
        MaxOutput = 8192
        Aliases = @("deepseek-coder", "ds-coder")
    }

    # General purpose models
    "gemma3" = @{
        Description = "Gemma 3 27B - Google's latest, outperforms Llama 405B on LMArena"
        IntelligenceScore = 17
        SupportsExtendedThinking = $false
        SupportsJson = $true
        Context = 128000
        MaxOutput = 32768
        Aliases = @("gemma3", "gemma", "google")
    }
    "phi4" = @{
        Description = "Phi-4 14B - Microsoft's efficient model, rivals 70B on reasoning"
        IntelligenceScore = 16
        SupportsExtendedThinking = $true
        SupportsJson = $true
        SupportsFunctionCalling = $true
        Context = 32768
        MaxOutput = 16384
        Aliases = @("phi4", "phi", "microsoft")
    }
    "dolphin3" = @{
        Description = "Dolphin3 8B - Uncensored, no refusals, based on Llama 3.1"
        IntelligenceScore = 12
        SupportsExtendedThinking = $false
        SupportsJson = $true
        Context = 131072
        MaxOutput = 32768
        Aliases = @("dolphin3", "dolphin", "uncensored")
    }
    "llama3.1" = @{
        Description = "Llama 3.1 8B - Fast model for web search, tool calling enabled"
        IntelligenceScore = 12
        SupportsExtendedThinking = $false
        SupportsJson = $true
        SupportsFunctionCalling = $true
        Context = 131072
        MaxOutput = 32768
        Aliases = @("llama3.1", "llama-8b", "fast-search")
    }
    "mistral" = @{
        Description = "Mistral 7B - Lightweight model for quick queries"
        IntelligenceScore = 10
        SupportsExtendedThinking = $false
        SupportsJson = $true
        SupportsFunctionCalling = $true
        Context = 32768
        MaxOutput = 8192
        Aliases = @("mistral", "mistral-7b", "quick")
    }
}

# Find PAL config path
function Find-PalConfigPath {
    $searchPaths = @(
        "$env:USERPROFILE\code\pal-mcp-server\conf\custom_models.json",
        "C:\Users\Egusto\code\pal-mcp-server\conf\custom_models.json",
        "$PSScriptRoot\..\pal-mcp-server\conf\custom_models.json",
        "$env:APPDATA\pal-mcp-server\custom_models.json"
    )

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            return (Resolve-Path $path).Path
        }
    }

    return $null
}

# Parse ollama list output
function Get-OllamaModels {
    $output = ollama list 2>&1
    $models = @()

    $lines = $output -split "`n" | Select-Object -Skip 1

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line -match "^(\S+)\s+(\S+)\s+(\d+\.?\d*\s*[GMK]B)\s+(.+)$") {
            $name = $Matches[1]
            $models += @{
                Name = $name
                ID = $Matches[2]
                Size = $Matches[3]
                Modified = $Matches[4].Trim()
                Is5090 = $name -match "-5090$"
                BaseName = $name -replace "-5090$", ""
            }
        }
    }

    return $models
}

# Load PAL config
function Get-PalConfig {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    return Get-Content $Path -Raw | ConvertFrom-Json
}

# Get base model name for capability lookup
function Get-BaseModelKey {
    param([string]$ModelName)

    # Remove -5090 suffix
    $base = $ModelName -replace "-5090$", ""

    # Remove size tag (e.g., :32b, :14b, :latest)
    $base = $base -replace ":\d+b(-.*)?$", ""
    $base = $base -replace ":latest(-.*)?$", ""

    return $base
}

# Build model entry for PAL config
function Build-ModelEntry {
    param(
        [hashtable]$OllamaModel,
        [hashtable]$Capabilities
    )

    $entry = @{
        model_name = $OllamaModel.Name
        description = if ($Capabilities.Description) {
            if ($OllamaModel.Is5090) {
                "$($Capabilities.Description) [5090 Optimized]"
            } else {
                $Capabilities.Description
            }
        } else {
            "Local Ollama model: $($OllamaModel.Name)"
        }
        intelligence_score = if ($Capabilities.IntelligenceScore) { $Capabilities.IntelligenceScore } else { 10 }
        supports_extended_thinking = if ($Capabilities.SupportsExtendedThinking) { $true } else { $false }
        supports_json_mode = if ($Capabilities.SupportsJson) { $true } else { $false }
        supports_images = if ($Capabilities.SupportsImages) { $true } else { $false }
        supports_function_calling = if ($Capabilities.SupportsFunctionCalling) { $true } else { $false }
        context_window = if ($Capabilities.Context) { $Capabilities.Context } else { 8192 }
        max_output_tokens = if ($Capabilities.MaxOutput) { $Capabilities.MaxOutput } else { 4096 }
        max_image_size_mb = if ($Capabilities.SupportsImages) { 20.0 } else { 0.0 }
        aliases = if ($Capabilities.Aliases) {
            # Add -5090 variants of aliases if this is a 5090 model
            $baseAliases = $Capabilities.Aliases
            if ($OllamaModel.Is5090) {
                $allAliases = @()
                foreach ($alias in $baseAliases) {
                    $allAliases += "$alias-5090"
                }
                $allAliases += $baseAliases  # Also keep base aliases
                $allAliases
            } else {
                $baseAliases
            }
        } else {
            @($OllamaModel.Name)
        }
    }

    return $entry
}

# Compare and show differences
function Show-Comparison {
    param(
        [array]$OllamaModels,
        [object]$PalConfig
    )

    $palModelNames = @()
    if ($PalConfig.models) {
        $palModelNames = $PalConfig.models | ForEach-Object { $_.model_name }
    }

    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "  PAL Config vs Ollama Models Comparison" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host ""

    # Models in Ollama but not in PAL
    $missingInPal = @()
    foreach ($model in $OllamaModels) {
        if ($model.Name -notin $palModelNames) {
            $missingInPal += $model
        }
    }

    if ($missingInPal.Count -gt 0) {
        Write-Host "Models in Ollama NOT in PAL config:" -ForegroundColor Yellow
        foreach ($model in $missingInPal) {
            $status = if ($model.Is5090) { "[5090]" } else { "" }
            Write-Host "  + $($model.Name) $status" -ForegroundColor Green
        }
        Write-Host ""
    }

    # Models in PAL but not in Ollama
    $extraInPal = @()
    $ollamaNames = $OllamaModels | ForEach-Object { $_.Name }
    foreach ($palModel in $PalConfig.models) {
        if ($palModel.model_name -notin $ollamaNames) {
            $extraInPal += $palModel.model_name
        }
    }

    if ($extraInPal.Count -gt 0) {
        Write-Host "Models in PAL config NOT in Ollama (may need removal):" -ForegroundColor Red
        foreach ($name in $extraInPal) {
            Write-Host "  - $name" -ForegroundColor Red
        }
        Write-Host ""
    }

    # Models with both base and -5090 variants
    $duplicates = @()
    foreach ($model in $OllamaModels) {
        if ($model.Is5090) {
            $base = $OllamaModels | Where-Object { $_.Name -eq $model.BaseName }
            if ($base) {
                $duplicates += @{
                    Base = $base.Name
                    Optimized = $model.Name
                }
            }
        }
    }

    if ($duplicates.Count -gt 0) {
        Write-Host "Models with both base and -5090 variants:" -ForegroundColor Cyan
        foreach ($dup in $duplicates) {
            Write-Host "  $($dup.Base)" -ForegroundColor Gray -NoNewline
            Write-Host " -> " -NoNewline
            Write-Host "$($dup.Optimized)" -ForegroundColor Green
        }
        Write-Host ""
    }

    # Summary
    Write-Host "Summary:" -ForegroundColor White
    Write-Host "  Ollama models:     $($OllamaModels.Count)"
    Write-Host "  PAL config models: $($PalConfig.models.Count)"
    Write-Host "  Missing in PAL:    $($missingInPal.Count)" -ForegroundColor $(if ($missingInPal.Count -gt 0) { "Yellow" } else { "Gray" })
    Write-Host "  Extra in PAL:      $($extraInPal.Count)" -ForegroundColor $(if ($extraInPal.Count -gt 0) { "Red" } else { "Gray" })

    # Show PAL tool recommendations based on installed models
    Show-ToolRecommendations $OllamaModels
}

# Show recommended models for PAL tools
function Show-ToolRecommendations {
    param([array]$OllamaModels)

    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Magenta
    Write-Host "  Recommended Models for PAL Tools" -ForegroundColor Magenta
    Write-Host "=" * 70 -ForegroundColor Magenta
    Write-Host ""

    # Find best models for each category
    $modelNames = $OllamaModels | ForEach-Object { $_.Name }

    # Reasoning models (for thinkdeep, challenge)
    $reasoningModels = @()
    foreach ($name in $modelNames) {
        $base = Get-BaseModelKey $name
        if ($script:ModelCapabilities[$base].SupportsExtendedThinking -or
            $name -match "deepseek-r1|qwen3|nemotron|phi4") {
            $score = if ($script:ModelCapabilities[$base].IntelligenceScore) {
                $script:ModelCapabilities[$base].IntelligenceScore
            } else { 10 }
            $reasoningModels += @{ Name = $name; Score = $score }
        }
    }
    $reasoningModels = $reasoningModels | Sort-Object { -$_.Score }

    # Coding models (for codereview, debug, refactor)
    $codingModels = @()
    foreach ($name in $modelNames) {
        if ($name -match "coder|codex|devstral|codellama") {
            $base = Get-BaseModelKey $name
            $score = if ($script:ModelCapabilities[$base].IntelligenceScore) {
                $script:ModelCapabilities[$base].IntelligenceScore
            } else { 12 }
            $codingModels += @{ Name = $name; Score = $score }
        }
    }
    $codingModels = $codingModels | Sort-Object { -$_.Score }

    # Fast models (for quick queries, web search)
    $fastModels = @()
    foreach ($name in $modelNames) {
        if ($name -match "llama3\.1:8b|mistral:7b|dolphin3:8b|qwen2\.5:3b") {
            $base = Get-BaseModelKey $name
            $score = if ($script:ModelCapabilities[$base].IntelligenceScore) {
                $script:ModelCapabilities[$base].IntelligenceScore
            } else { 10 }
            $fastModels += @{ Name = $name; Score = $score }
        }
    }
    $fastModels = $fastModels | Sort-Object { -$_.Score }

    # Print recommendations
    Write-Host "THINKDEEP / CHALLENGE (reasoning, extended thinking):" -ForegroundColor Yellow
    if ($reasoningModels.Count -gt 0) {
        $top = $reasoningModels | Select-Object -First 3
        foreach ($m in $top) {
            $star = if ($m -eq $top[0]) { "*" } else { " " }
            Write-Host "  $star $($m.Name)" -ForegroundColor $(if ($m -eq $top[0]) { "Green" } else { "White" }) -NoNewline
            Write-Host " (score: $($m.Score))" -ForegroundColor Gray
        }
    } else {
        Write-Host "  (no reasoning models found - consider: deepseek-r1, qwen3, nemotron)" -ForegroundColor Red
    }
    Write-Host ""

    Write-Host "CONSENSUS (multi-model debate, diverse perspectives):" -ForegroundColor Yellow
    $consensusModels = @()
    # Pick top from each category for diversity
    if ($reasoningModels.Count -gt 0) { $consensusModels += $reasoningModels[0] }
    if ($codingModels.Count -gt 0) { $consensusModels += $codingModels[0] }
    # Add a different reasoning model if available
    if ($reasoningModels.Count -gt 1) { $consensusModels += $reasoningModels[1] }

    if ($consensusModels.Count -ge 2) {
        Write-Host "  Suggested consensus panel:" -ForegroundColor White
        $stances = @("for", "against", "neutral")
        $i = 0
        foreach ($m in ($consensusModels | Select-Object -First 3)) {
            $stance = $stances[$i % 3]
            Write-Host "    - $($m.Name) " -NoNewline -ForegroundColor Cyan
            Write-Host "($stance)" -ForegroundColor Gray
            $i++
        }
    } else {
        Write-Host "  (need 2+ diverse models - install more for better consensus)" -ForegroundColor Red
    }
    Write-Host ""

    Write-Host "CODEREVIEW / DEBUG / REFACTOR (coding analysis):" -ForegroundColor Yellow
    if ($codingModels.Count -gt 0) {
        $top = $codingModels | Select-Object -First 3
        foreach ($m in $top) {
            $star = if ($m -eq $top[0]) { "*" } else { " " }
            Write-Host "  $star $($m.Name)" -ForegroundColor $(if ($m -eq $top[0]) { "Green" } else { "White" }) -NoNewline
            Write-Host " (score: $($m.Score))" -ForegroundColor Gray
        }
    } else {
        Write-Host "  (no coding models found - consider: qwen2.5-coder, devstral, codexor)" -ForegroundColor Red
    }
    Write-Host ""

    Write-Host "CHAT / QUICK QUERIES (fast responses):" -ForegroundColor Yellow
    if ($fastModels.Count -gt 0) {
        foreach ($m in $fastModels) {
            Write-Host "  * $($m.Name)" -ForegroundColor Green
        }
    } else {
        Write-Host "  (no fast models found - consider: llama3.1:8b, mistral:7b)" -ForegroundColor Red
    }
    Write-Host ""

    Write-Host "* = recommended for this tool category" -ForegroundColor DarkGray
}

# Update PAL config
function Update-PalConfig {
    param(
        [string]$ConfigPath,
        [array]$OllamaModels
    )

    # Determine which models to include
    $modelsToInclude = @()

    # Group by base name
    $grouped = @{}
    foreach ($model in $OllamaModels) {
        $baseName = $model.BaseName
        if (-not $grouped.ContainsKey($baseName)) {
            $grouped[$baseName] = @()
        }
        $grouped[$baseName] += $model
    }

    foreach ($baseName in $grouped.Keys) {
        $variants = $grouped[$baseName]

        if ($Prefer5090) {
            # Prefer -5090 variant if it exists
            $optimized = $variants | Where-Object { $_.Is5090 }
            if ($optimized) {
                $modelsToInclude += $optimized
            } else {
                $modelsToInclude += $variants[0]
            }
        } else {
            # Include all variants
            $modelsToInclude += $variants
        }
    }

    # Build new config
    $newModels = @()
    foreach ($model in ($modelsToInclude | Sort-Object { $_.Name })) {
        $baseKey = Get-BaseModelKey $model.Name
        $capabilities = $script:ModelCapabilities[$baseKey]

        # Try with full name if base key not found
        if (-not $capabilities) {
            $capabilities = $script:ModelCapabilities[$model.BaseName]
        }
        if (-not $capabilities) {
            $capabilities = @{}
        }

        $entry = Build-ModelEntry $model $capabilities
        $newModels += $entry
    }

    # Sort by intelligence score descending
    $newModels = $newModels | Sort-Object { -$_.intelligence_score }

    $newConfig = @{
        models = $newModels
        _README = @{
            description = "Model metadata for local Ollama models via Custom provider"
            documentation = "https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/custom_models.md"
            usage = "Each entry is advertised by the Custom provider. Aliases are case-insensitive."
            field_notes = "Matches providers/shared/model_capabilities.py"
            updated_by = "update-pal-config.ps1 from ollama-rtx-setup"
            last_updated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            prefer_5090 = $Prefer5090.IsPresent
        }
    }

    # Backup existing config
    if (Test-Path $ConfigPath) {
        $backupPath = "$ConfigPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $ConfigPath $backupPath
        Write-Status "Backed up existing config to: $backupPath"
    }

    # Write new config
    $newConfig | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Encoding UTF8

    return $newModels.Count
}

# Main
function Main {
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "  PAL MCP Server Config Updater" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""

    # Find PAL config
    $configPath = if ($PalConfigPath) { $PalConfigPath } else { Find-PalConfigPath }

    if (-not $configPath) {
        Write-Err "Could not find PAL MCP Server custom_models.json"
        Write-Host "  Specify path with: -PalConfigPath <path>" -ForegroundColor Gray
        exit 1
    }

    Write-Status "PAL config: $configPath"

    # Get Ollama models
    $ollamaModels = Get-OllamaModels

    if ($ollamaModels.Count -eq 0) {
        Write-Err "No Ollama models found. Is Ollama running?"
        exit 1
    }

    Write-Status "Found $($ollamaModels.Count) Ollama model(s)"

    # Load current PAL config
    $palConfig = Get-PalConfig $configPath

    if (-not $palConfig) {
        Write-Warn "PAL config not found or empty, will create new one"
        $palConfig = @{ models = @() }
    }

    # Show comparison
    Show-Comparison $ollamaModels $palConfig

    # If just listing, stop here
    if ($List) {
        return
    }

    Write-Host ""

    # Confirm update
    if (-not $NoPrompt) {
        $mode = if ($Prefer5090) { " (preferring -5090 variants)" } else { " (including all variants)" }
        $response = Read-Host "Update PAL config with $($ollamaModels.Count) models$($mode)? [y/N]"
        if ($response -notmatch "^[Yy]") {
            Write-Status "Update cancelled"
            return
        }
    }

    # Update config
    $count = Update-PalConfig $configPath $ollamaModels

    Write-Host ""
    Write-Success "Updated PAL config with $count model(s)"
    Write-Host ""
    Write-Host "Restart PAL MCP Server to apply changes:" -ForegroundColor Yellow
    Write-Host "  - Restart Claude Desktop, or" -ForegroundColor Gray
    Write-Host "  - Run: powershell -File start-pal.ps1" -ForegroundColor Gray
}

Main
