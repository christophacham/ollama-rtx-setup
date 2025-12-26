---
sidebar_position: 3
---

# Backup & Restore

Move your Ollama models between machines or external storage.

## Why Backup Models?

- **Large downloads** - A 70B model is 40GB+. Re-downloading wastes time and bandwidth.
- **Machine migration** - Moving to a new PC shouldn't mean re-downloading everything.
- **External storage** - Store models on a fast NVMe drive instead of your boot SSD.
- **Disaster recovery** - Hardware fails. Backups save the day.

## Quick Reference

```powershell
# Check what you have
.\backup-ollama-models.ps1 -Info

# Backup to external drive
.\backup-ollama-models.ps1 -Backup -Destination "E:\ollama-backup"

# Restore from backup
.\backup-ollama-models.ps1 -Restore -Source "E:\ollama-backup"
```

## Understanding Model Storage

### Default Location

```
Windows: C:\Users\<username>\.ollama\models\
Linux:   ~/.ollama/models/
```

### Directory Structure

```
.ollama/
├── models/
│   ├── manifests/           # Model metadata
│   │   └── registry.ollama.ai/
│   │       └── library/
│   │           └── qwen3/
│   │               └── 32b   # Model manifest
│   └── blobs/                # Actual model weights
│       ├── sha256-abc123...  # Large binary files
│       └── sha256-def456...
└── history                   # Chat history (optional)
```

### Size Estimates

| Model | Manifest | Blobs | Total |
|-------|----------|-------|-------|
| 7B Q4 | ~1KB | ~4GB | ~4GB |
| 32B Q4 | ~1KB | ~18GB | ~18GB |
| 70B Q4 | ~1KB | ~40GB | ~40GB |

## Backup Methods

### Method 1: Using the Script (Recommended)

The `backup-ollama-models.ps1` script handles everything:

```powershell
# Full backup with progress
.\backup-ollama-models.ps1 -Backup -Destination "E:\ollama-backup"
```

**Features:**
- Stops Ollama before backup (prevents corruption)
- Uses robocopy for reliable large file transfer
- Shows progress and handles errors
- Validates disk space before starting

### Method 2: Manual Copy

If you prefer manual control:

```powershell
# Stop Ollama first!
ollama stop

# Copy using robocopy (handles large files well)
robocopy "$env:USERPROFILE\.ollama\models" "E:\ollama-backup\models" /E /Z /MT:8

# Restart Ollama
ollama serve
```

### Method 3: Moving Model Directory

Change where Ollama stores models permanently:

```powershell
# 1. Stop Ollama
ollama stop

# 2. Move existing models
Move-Item "$env:USERPROFILE\.ollama\models" "D:\ollama-models"

# 3. Set environment variable
[Environment]::SetEnvironmentVariable("OLLAMA_MODELS", "D:\ollama-models", "User")

# 4. Restart Ollama
ollama serve
```

## Restore Methods

### From Backup Script

```powershell
.\backup-ollama-models.ps1 -Restore -Source "E:\ollama-backup"
```

### Manual Restore

```powershell
# Stop Ollama
ollama stop

# Restore files
robocopy "E:\ollama-backup\models" "$env:USERPROFILE\.ollama\models" /E /Z /MT:8

# Restart Ollama
ollama serve

# Verify
ollama list
```

### To a Different Machine

1. Copy backup to new machine (USB drive, network share, etc.)
2. Run restore:
```powershell
.\backup-ollama-models.ps1 -Restore -Source "E:\ollama-backup"
```

## Storage Recommendations

### Internal SSD vs External

| Storage Type | Speed | Use Case |
|--------------|-------|----------|
| NVMe (internal) | Fastest | Primary model storage |
| SATA SSD (internal) | Fast | Good secondary option |
| USB 3.2 SSD | Medium | Portable backup |
| USB HDD | Slow | Archive only |

### Model Load Times by Storage

| Storage | 7B Load | 32B Load | 70B Load |
|---------|---------|----------|----------|
| NVMe | 0.8s | 3.2s | 8.1s |
| SATA SSD | 1.2s | 4.8s | 12.0s |
| USB 3.2 SSD | 2.5s | 10.0s | 25.0s |

### External Drive Setup

For fastest external storage, use a USB 3.2 Gen 2 NVMe enclosure:

```powershell
# Move models to external NVMe
$env:OLLAMA_MODELS = "E:\ollama-models"
[Environment]::SetEnvironmentVariable("OLLAMA_MODELS", "E:\ollama-models", "User")
```

## Selective Backup

### Backup Specific Models

```powershell
# Find model blob hashes
ollama show qwen3:32b --modelfile

# Copy only those blobs
$blobs = @("sha256-abc123", "sha256-def456")
foreach ($blob in $blobs) {
    Copy-Item "$env:USERPROFILE\.ollama\models\blobs\$blob" "E:\backup\blobs\"
}
```

### Exclude Large Models

```powershell
# Backup everything except 70B models
robocopy "$env:USERPROFILE\.ollama\models" "E:\backup" /E /XF "*70b*"
```

## Troubleshooting

### "Access denied" errors

Ollama may have files locked:

```powershell
# Force stop Ollama
Stop-Process -Name "ollama*" -Force

# Then retry backup
```

### "Disk space" errors

Check available space before backup:

```powershell
.\backup-ollama-models.ps1 -Info
# Shows: Current models size, Destination free space
```

### Models don't appear after restore

Manifest files may be missing:

```powershell
# Re-pull model (uses existing blobs if present)
ollama pull qwen3:32b
```

### Corrupted backup

If backup was interrupted:

```powershell
# Verify backup integrity
robocopy "E:\backup" "E:\backup-verify" /E /L /LOG:verify.log
# Check verify.log for errors
```

## Automation

### Scheduled Backups

Create a scheduled task:

```powershell
# Create daily backup task
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-File C:\path\to\backup-ollama-models.ps1 -Backup -Destination E:\backup"
$trigger = New-ScheduledTaskTrigger -Daily -At "3:00AM"
Register-ScheduledTask -TaskName "Ollama Backup" -Action $action -Trigger $trigger
```

### Incremental Backups

Robocopy only copies changed files by default:

```powershell
# Incremental backup (only changed files)
.\backup-ollama-models.ps1 -Backup -Destination "E:\backup"
# Second run is much faster
```
