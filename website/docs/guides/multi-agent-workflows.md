---
sidebar_position: 5
sidebar_label: Multi-Agent Workflows
---

# Multi-Agent Workflows

Advanced patterns for using multiple AI CLIs together on the same project.

## The Coder + Observer Pattern

Run two AI agents simultaneously: one writes code, one debugs/reviews. This prevents tunnel vision and catches issues early.

```
┌─────────────────────────────────────────────────────────────┐
│                    Dual CLI Workflow                        │
│                                                             │
│  Terminal 1 (Coder)          Terminal 2 (Observer)         │
│  ┌─────────────────┐         ┌─────────────────┐           │
│  │  Gemini CLI     │         │  Claude Code    │           │
│  │  - Edits files  │   ←→    │  - READ ONLY    │           │
│  │  - Builds       │         │  - Analyzes     │           │
│  │  - Runs tests   │         │  - Explains     │           │
│  └─────────────────┘         └─────────────────┘           │
│           ↓                           ↓                     │
│     Makes changes              Reviews changes              │
│           ↓                           ↓                     │
│      You verify ←──── Human in the loop ────→ You verify   │
└─────────────────────────────────────────────────────────────┘
```

### Why This Works

- **Coder** focuses on implementation, can get tunnel vision
- **Observer** spots issues the coder misses (different model = different blindspots)
- **Human** coordinates and makes final decisions
- **No conflicts** - only one agent edits files

## Setting Up the Coder (Gemini CLI)

Gemini CLI reads `GEMINI.md` from your project root for context.

### Create Project Instructions

**`your-project/GEMINI.md`:**

```markdown
# Project Name - Coder Instructions

You are the CODER for this project. Make focused changes, build and test after each.

## Current Task
[Describe what you're working on]

## Priority
1. [First thing to try]
2. [Second thing to try]
3. [Fallback approach]

## Commands
- Build: `cargo build` (or your build command)
- Test: `cargo test`
- Run: `cargo run`

## Research
Use web search if stuck on framework patterns.

## Stack
- [Your tech stack]
- [Frameworks]
- [Key libraries]
```

### Start Gemini as Coder

```bash
cd your-project
gemini
```

Gemini automatically reads `GEMINI.md` and follows those instructions.

## Setting Up the Observer (Claude Code)

Claude Code can be given a system prompt via the `-p` flag.

### Quick Start (Inline Prompt)

```bash
claude -p "You are a READ-ONLY observer for C:\path\to\project. Never edit files. Only read, analyze, and explain issues when I ask. Say 'Observer ready'."
```

### With a Prompt File

Create **`observer-prompt.md`** in your project:

```markdown
You are the OBSERVER for this project. READ-ONLY mode.

## Rules
- NEVER edit files, only read/list/analyze
- NEVER run build commands
- Investigate when asked, report findings clearly
- Let the CODER (in another terminal) make fixes

## Project Context
- Path: C:\Users\You\code\your-project
- Stack: [Your stack]
- Issue: [Current problem]

## Key Files to Watch
- src/main.rs
- src/components/
- config/

When asked, read files and explain what's wrong. Suggest fixes but don't implement them.
```

Then start Claude:

```bash
claude -p "Read observer-prompt.md and follow those instructions. Say 'Observer ready' when done."
```

## Example: Debugging a Black Viewport

Real example from a Dioxus + Three.js project:

### Coder's GEMINI.md

```markdown
# Layered Slicer - Coder Instructions

You are the CODER. Make focused changes, build and test after each.

## Current Task
Fix the viewport - it's black but should show a cyan Three.js build plate grid.

## Priority
1. Check if assets/viewport/ has index.html and viewport.js
2. Check what src/viewport.rs is rendering
3. Add a visible placeholder first (cyan background + text)
4. Then fix Three.js integration

## Commands
- Build: `cargo build -p layered-dioxus`
- Run: `cargo run -p layered-dioxus`

## Stack
- Dioxus 0.7 (desktop)
- Three.js in iframe for 3D viewport
- layerkit-core for mesh/slicing
```

### Observer's Prompt

```bash
claude -p "You are a READ-ONLY observer for C:\Users\Egusto\code\slicer. Never edit files. Only read, analyze, and explain. Current issue: viewport is black. Key files: src/viewport.rs, src/components/layout.rs, assets/viewport/. Say 'Observer ready'."
```

### Workflow

1. **You to Observer:** "Check viewport.rs - what's it rendering?"
2. **Observer reads, reports:** "It's creating an iframe pointing to `/viewport/index.html` but I don't see that file in assets..."
3. **You to Coder:** "The observer says index.html is missing. Create it."
4. **Coder creates file, builds**
5. **You to Observer:** "Check if it works now"
6. **Repeat until fixed**

## System Prompts Reference

### Claude Code Flags

```bash
# Inline system prompt
claude -p "Your instructions here"

# Read from file
claude -p "Read ./my-prompt.md and follow it"

# Continue previous session
claude --continue

# Print current system prompt (debug)
claude --print-system-prompt
```

### Gemini CLI Files

| File | Purpose |
|------|---------|
| `GEMINI.md` | Project-specific instructions (in project root) |
| `~/.gemini/settings.json` | Global settings + MCP servers |

### Codex CLI Config

```toml
# ~/.codex/config.toml

[defaults]
provider = "ollama"
model = "qwen2.5-coder:32b"

[model_profiles.reasoning]
provider = "ollama"
model = "deepseek-r1:32b"
```

## Alternative Patterns

### Same CLI, Different Roles

Run two instances of the same CLI with different prompts:

**Terminal 1 - Implementer:**
```bash
claude -p "You implement features. Focus on writing code."
```

**Terminal 2 - Reviewer:**
```bash
claude -p "You review code. Never edit, only analyze and suggest."
```

### PAL Consensus for Decisions

When stuck, use PAL's consensus tool to get multiple model opinions:

```bash
# In either terminal
pal consensus "Should we use iframe or web component for the Three.js viewport?"
```

### Web Search for Research

```bash
# Coder researching a pattern
pal web-search "Dioxus iframe communication 2025"

# Observer checking documentation
pal research "Three.js OrbitControls setup"
```

## Tips

1. **Keep the coder focused** - Give specific tasks, not vague goals
2. **Observer stays read-only** - If it starts editing, restart with stricter prompt
3. **Coordinate via chat** - Copy relevant findings between terminals
4. **Human decides** - You're the architect, they're the tools
5. **Use git** - Commit working states so you can rollback coder mistakes

## Quick Reference

| Role | CLI | Edits Files | System Prompt |
|------|-----|-------------|---------------|
| Coder | Gemini | Yes | `GEMINI.md` in project |
| Observer | Claude | No | `-p` flag or prompt file |
| Research | PAL | No | Via MCP tools |

```bash
# Start coder
cd project && gemini

# Start observer
claude -p "READ-ONLY observer for $(pwd). Never edit. Say 'ready'."

# Get consensus
pal consensus "Which approach is better?"
```
