---
sidebar_position: 3
---

# Container Image Sync

Mirror upstream container images to your own GitHub Container Registry.

## Why Mirror Images?

### Reliability
Upstream registries can have outages. Your own mirror is always available.

### Speed
GitHub Container Registry often has better CDN coverage for your region.

### Version Control
Track exactly which image versions you're using. No surprise updates.

### Air-gapped Environments
Deploy to systems without internet access using pre-mirrored images.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    UPSTREAM REGISTRIES                      │
│  ghcr.io/open-webui/open-webui:cuda                        │
│  docker.io/searxng/searxng:latest                          │
│  docker.io/itzcrazykns1337/perplexica-backend:main         │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼ GitHub Actions (daily)
┌─────────────────────────────────────────────────────────────┐
│              YOUR REGISTRY                                  │
│  ghcr.io/YOUR_USERNAME/ollama-rtx-setup/open-webui:cuda    │
│  ghcr.io/YOUR_USERNAME/ollama-rtx-setup/searxng:latest     │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ container-versions.json (tracks digests)
┌─────────────────────────────────────────────────────────────┐
│              Your local setup                               │
│  setup-ollama-websearch.ps1 -UseLocalRegistry              │
└─────────────────────────────────────────────────────────────┘
```

## Setup

### 1. Enable GitHub Packages

In your repository:
1. Go to **Settings → General → Features**
2. Enable **Packages**

### 2. Configure Workflow

The sync workflow is already included at `.github/workflows/sync-containers.yml`:

```yaml
name: Sync Container Images
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM UTC
  workflow_dispatch:      # Manual trigger

jobs:
  sync:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
    steps:
      - uses: actions/checkout@v4
      - name: Login to GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      - name: Run sync script
        run: pwsh ./sync-container-images.ps1 -Sync
      # ... commits version updates
```

### 3. Trigger First Sync

Go to **Actions → Sync Container Images → Run workflow**.

## Usage

### Check Status

```powershell
.\sync-container-images.ps1
```

Output:
```
========================================
  Container Image Sync
========================================

[Authentication Check]
  [OK] Container engine: docker

[Checking Images]

  open-webui:cuda
    Upstream: ghcr.io/open-webui/open-webui:cuda
    Upstream digest: sha256:623dc171b7e28...
  [CURRENT]     Up to date

  searxng:latest
    Upstream: docker.io/searxng/searxng:latest
    Upstream digest: sha256:3c041584da716...
  [UPDATE]     Upstream changed

========================================
  1 update(s) available
  Run with -Sync to apply
========================================
```

### Sync Updates

```powershell
.\sync-container-images.ps1 -Sync
```

### Force Sync All

```powershell
.\sync-container-images.ps1 -Force
```

### Sync Specific Image

```powershell
.\sync-container-images.ps1 -Sync -Image "open-webui:cuda"
```

## Version Tracking

### container-versions.json

Tracks the state of all mirrored images:

```json
{
  "registry": "ghcr.io/christophacham/ollama-rtx-setup",
  "last_check": "2025-12-26T13:54:37Z",
  "images": {
    "open-webui:cuda": {
      "upstream": "ghcr.io/open-webui/open-webui:cuda",
      "upstream_digest": "sha256:623dc171b7e28...",
      "local_digest": "sha256:623dc171b7e28...",
      "synced_at": "2025-12-26T13:54:42Z",
      "status": "synced"
    }
  }
}
```

### Status Values

| Status | Meaning |
|--------|---------|
| `synced` | Local matches upstream |
| `pending` | Not yet mirrored |
| `outdated` | Upstream has newer version |

## Using Mirrored Images

### In Setup Script

```powershell
.\setup-ollama-websearch.ps1 -UseLocalRegistry
```

This uses images from your registry instead of upstream.

### Manually

```powershell
# Instead of:
docker pull ghcr.io/open-webui/open-webui:cuda

# Use:
docker pull ghcr.io/YOUR_USERNAME/ollama-rtx-setup/open-webui:cuda
```

## Images Tracked

| Local Name | Upstream |
|------------|----------|
| `open-webui:cuda` | `ghcr.io/open-webui/open-webui:cuda` |
| `open-webui:main` | `ghcr.io/open-webui/open-webui:main` |
| `searxng:latest` | `docker.io/searxng/searxng:latest` |
| `perplexica-backend:main` | `docker.io/itzcrazykns1337/perplexica-backend:main` |
| `perplexica-frontend:main` | `docker.io/itzcrazykns1337/perplexica-frontend:main` |

## Adding New Images

Edit `container-versions.json`:

```json
{
  "images": {
    "my-new-image:tag": {
      "upstream": "docker.io/someorg/image:tag",
      "upstream_digest": null,
      "local_digest": null,
      "synced_at": null,
      "status": "pending"
    }
  }
}
```

Then run:
```powershell
.\sync-container-images.ps1 -Sync -Image "my-new-image:tag"
```

## Automation

### GitHub Actions Schedule

The workflow runs daily at 6 AM UTC. Customize in `.github/workflows/sync-containers.yml`:

```yaml
on:
  schedule:
    - cron: '0 6 * * *'   # Daily
    - cron: '0 */6 * * *' # Every 6 hours
```

### Manual Trigger

1. Go to **Actions → Sync Container Images**
2. Click **Run workflow**
3. Select branch and confirm

### Commit Behavior

After syncing, the workflow commits updated `container-versions.json`:

```
chore: Update container versions

Updates digests for:
- open-webui:cuda
- searxng:latest
```

## Troubleshooting

### "Not logged in to ghcr.io"

For local runs, log in first:
```powershell
docker login ghcr.io -u YOUR_USERNAME
# Enter your GitHub PAT with write:packages scope
```

### "Cannot fetch upstream digest"

The upstream image may not exist or be inaccessible:
```powershell
# Test manually
docker manifest inspect ghcr.io/open-webui/open-webui:cuda
```

### Workflow Fails

Check Actions logs for details. Common issues:
- Missing `packages: write` permission
- Rate limiting from upstream registry
- Disk space on GitHub runner

### Images Not Updating

The workflow compares digests. If digests match, no sync occurs:
```powershell
# Force sync to refresh
.\sync-container-images.ps1 -Force
```
