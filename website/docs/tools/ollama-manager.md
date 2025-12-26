---
sidebar_position: 1
---

# Ollama Manager

A terminal UI (TUI) for managing Ollama models.

## Why a TUI?

The command line is powerful but repetitive. Instead of typing:
```powershell
ollama ps          # What's loaded?
ollama list        # What's available?
ollama run qwen3   # Load this one
ollama stop qwen3  # Unload it
```

Just run `ollama-manager.exe` and use keyboard shortcuts.

## Installation

### Pre-built Binary

Download from the repository:
```powershell
cd ollama-manager
.\ollama-manager.exe
```

### Build from Source

Requires Go 1.21+ or Docker/Podman:

```powershell
# Using container (no local Go needed)
cd ollama-manager
.\build.ps1

# Using local Go
.\build.ps1 -Local
```

## Usage

### Starting the Manager

```powershell
.\ollama-manager.exe
```

You'll see a list of all installed models with their status:

```
┌──────────────────────────────────────────────────────────┐
│  Ollama Manager                                          │
├──────────────────────────────────────────────────────────┤
│  > qwen3:32b                              [LOADED]       │
│    deepseek-r1:32b                                       │
│    llama3.3:70b-instruct-q4_K_M                          │
│    llama3.1:8b                                           │
│    mistral:7b                                            │
│    phi-4:14b                                             │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  r: run  s: stop  u: unload all  R: refresh  q: quit    │
└──────────────────────────────────────────────────────────┘
```

### Keyboard Controls

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate models |
| `r` / `Enter` | Run selected model (interactive chat) |
| `s` | Stop selected model (unload from VRAM) |
| `u` | Unload ALL models |
| `R` | Refresh model list |
| `q` | Quit |

### Running a Model

1. Navigate to a model with arrow keys
2. Press `r` or `Enter`
3. The TUI exits and opens an interactive chat session
4. Type `/bye` to exit chat

### Stopping Models

Models stay loaded in VRAM for fast reuse. To free memory:

1. Navigate to a loaded model (shows `[LOADED]`)
2. Press `s` to stop it
3. Or press `u` to unload ALL models

## How It Works

The manager is built with:
- **[BubbleTea](https://github.com/charmbracelet/bubbletea)** - TUI framework
- **[Lipgloss](https://github.com/charmbracelet/lipgloss)** - Styling

It calls Ollama CLI commands:
```go
// List models
exec.Command("ollama", "list")

// Check what's loaded
exec.Command("ollama", "ps")

// Run model
exec.Command("ollama", "run", modelName)

// Stop model
exec.Command("ollama", "stop", modelName)
```

## Source Code

The full source is in `ollama-manager/main.go`:

```go
package main

import (
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/lipgloss"
)

type model struct {
    models   []modelInfo
    cursor   int
    selected string
}

// ... see full source in repository
```

## Building

### With Docker/Podman (Recommended)

No local Go installation required:

```powershell
cd ollama-manager
.\build.ps1
```

This:
1. Builds a Docker image with Go
2. Cross-compiles for Windows
3. Extracts the `.exe` file

### With Local Go

If you have Go installed:

```powershell
cd ollama-manager
.\build.ps1 -Local
```

Or manually:
```powershell
go mod tidy
go build -ldflags="-s -w" -o ollama-manager.exe .
```

### Build Output

```
Build complete! Binary: ollama-manager.exe (2.57 MB)
```

## Customization

### Adding Features

Fork the repository and modify `main.go`:

```go
// Example: Add model deletion
case "d":
    exec.Command("ollama", "rm", m.models[m.cursor].name).Run()
```

### Changing Styles

Modify the Lipgloss styles:

```go
var (
    titleStyle = lipgloss.NewStyle().
        Bold(true).
        Foreground(lipgloss.Color("86"))  // Change color
)
```

## Troubleshooting

### "ollama not found"

The manager calls `ollama` CLI. Ensure it's in your PATH:

```powershell
ollama --version
```

### Models not showing

Refresh the list with `R` key.

### "Access denied" on Windows

Run PowerShell as Administrator if models are in a protected directory.

### Terminal rendering issues

Ensure your terminal supports ANSI colors. Windows Terminal recommended.

## Alternatives

If a TUI isn't your style:

### CLI Commands
```powershell
ollama list    # List models
ollama ps      # Show loaded
ollama stop X  # Unload model
```

### Open WebUI
Web interface at http://localhost:3000 with visual model selection.

### API
```powershell
# List via API
curl http://localhost:11434/api/tags

# Load model via API
curl http://localhost:11434/api/generate -d '{"model":"qwen3:32b"}'
```
