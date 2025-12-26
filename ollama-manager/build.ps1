# Ollama Manager Build Script
# Builds Windows exe using Docker or Podman (no Go required locally)

param(
    [switch]$Local  # Use local Go instead of container
)

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot

function Find-ContainerEngine {
    if (Get-Command "podman" -ErrorAction SilentlyContinue) { return "podman" }
    if (Get-Command "docker" -ErrorAction SilentlyContinue) { return "docker" }
    return $null
}

if ($Local) {
    Write-Host "Building locally with Go..." -ForegroundColor Cyan
    if (-not (Get-Command "go" -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Go not found. Install Go or use container build (no -Local flag)" -ForegroundColor Red
        exit 1
    }
    go mod tidy
    go build -ldflags="-s -w" -o ollama-manager.exe .
} else {
    $engine = Find-ContainerEngine
    if (-not $engine) {
        Write-Host "Error: Neither Docker nor Podman found. Install one or use -Local with Go" -ForegroundColor Red
        exit 1
    }

    Write-Host "Building with $engine..." -ForegroundColor Cyan

    # Build the image
    & $engine build -t ollama-manager-build .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed!" -ForegroundColor Red
        exit 1
    }

    # Extract binary from container
    $container = & $engine create ollama-manager-build
    & $engine cp "${container}:/ollama-manager.exe" ./ollama-manager.exe
    & $engine rm $container | Out-Null

    # Cleanup image
    & $engine rmi ollama-manager-build -f 2>$null | Out-Null
}

if (Test-Path "ollama-manager.exe") {
    $size = [math]::Round((Get-Item "ollama-manager.exe").Length / 1MB, 2)
    Write-Host "Built: ollama-manager.exe ($size MB)" -ForegroundColor Green
} else {
    Write-Host "Build failed - exe not found!" -ForegroundColor Red
    exit 1
}

Pop-Location
