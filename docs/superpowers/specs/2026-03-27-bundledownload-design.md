# BundleDownload — Design Spec

## Context

Onboarding new developers requires installing a long list of CLI tools and applications. Each tool has different install methods per OS, some depend on others (npm-based CLIs need Node), and the process is tedious and error-prone. BundleDownload solves this with a single-command installer that detects the OS, resolves dependencies, and installs everything in the optimal order — with support for presets so a team lead can define "our stack" once.

**Starting with:** CLI tool (bash script + PowerShell script)
**Future form factors:** Web app, desktop app, standalone binary

---

## Supported Tools (v1)

| ID | Tool | Version Check | Requires |
|---|---|---|---|
| `git` | Git | `git --version` | — |
| `node` | Node.js (via fnm) | `node --version` | — |
| `gh` | GitHub CLI | `gh --version` | — |
| `gcloud` | Google Cloud CLI | `gcloud --version` | — |
| `az` | Azure CLI | `az --version` | — |
| `aws` | AWS CLI | `aws --version` | — |
| `vercel` | Vercel CLI | `vercel --version` | `node` |
| `supabase` | Supabase CLI | `supabase --version` | — |
| `wrangler` | Cloudflare Wrangler | `wrangler --version` | `node` |
| `claude-code` | Claude Code | `claude --version` | — |
| `whisperflow` | WhisperFlow | `whisperflow --version` | — |
| `tabby` | Tabby Terminal | — (desktop app) | — |

---

## Architecture

### Entry Points

Two scripts, one per platform family:

- **`install.sh`** — Bash script for macOS and Linux
- **`install.ps1`** — PowerShell script for Windows

Invocation:
```bash
# Mac/Linux
curl -fsSL https://bundledownload.dev/install.sh | bash

# Windows (PowerShell)
irm https://bundledownload.dev/install.ps1 | iex

# With preset
curl -fsSL https://bundledownload.dev/install.sh | bash -s -- --preset dannys-stack

# With config file
curl -fsSL https://bundledownload.dev/install.sh | bash -s -- --config ./team-tools.json

# Non-interactive (for CI/scripts)
curl -fsSL https://bundledownload.dev/install.sh | bash -s -- --preset full-stack --yes
```

### OS Detection

**`install.sh`** detects:
- macOS (arm64 vs x86_64) — uses `brew` as primary package manager
- Linux (Debian/Ubuntu vs Fedora/RHEL vs Arch) — uses `apt`/`dnf`/`pacman` + direct downloads

**`install.ps1`** detects:
- Windows version — uses `winget` as primary package manager

If the preferred package manager isn't available, the script installs it first (Homebrew on macOS, winget should already exist on modern Windows).

### Dependency-Aware Install Order

Tools are installed in phases to respect dependencies:

```
Phase 1 (Foundations):  git, node (via fnm)
Phase 2 (NPM tools):   vercel, wrangler, supabase (npm install -g)
Phase 3 (Standalone):   gh, aws, az, gcloud, claude-code
Phase 4 (Apps):         tabby, whisperflow
```

**Within each phase, installs run in parallel** where the OS/package manager supports it. For example, on macOS Phase 3 tools can all `brew install` concurrently. On Windows, `winget` handles its own sequencing.

### Already-Installed Detection

Before installing each tool, check if it exists:

1. Run the version check command (e.g., `git --version`)
2. If found: print `[already installed] git v2.43.0` in green, skip
3. If not found: proceed with install

No `--update` flag in v1 — keep it simple. Can add later.

### Interactive Mode (default)

When run without `--preset` or `--yes`:

1. Print banner with detected OS info
2. Show checklist of all tools with arrow keys + space to toggle
3. Pre-check tools that are in the default preset (`dannys-stack`)
4. Shortcuts: `a` = select all, `n` = select none, `p` = load a preset
5. Enter = start installing selected tools
6. Show progress with spinners/checkmarks per tool

**Bash implementation:** Use `tput` and ANSI escape codes for the interactive picker. No external dependencies.

**PowerShell implementation:** Use `Write-Host` with colors and `[Console]::ReadKey()` for input.

### Non-Interactive Mode

With `--preset <name>` or `--config <path>` plus `--yes`:
- Skip the picker entirely
- Install all tools in the preset/config
- Print progress as each tool installs
- Exit 0 on success, non-zero if any tool failed

---

## Preset System

### Built-in Presets

Hardcoded in the scripts:

| Preset | Tools |
|---|---|
| `dannys-stack` | node, git, gh, claude-code, vercel, supabase, wrangler, tabby |
| `frontend-dev` | node, git, gh, vercel, wrangler |
| `cloud-ops` | git, gh, aws, az, gcloud |
| `full-stack` | All tools |

### External Config Files

JSON format (`bundledownload.json`):

```json
{
  "name": "my-team",
  "tools": ["node", "git", "gh", "vercel", "supabase", "claude-code"],
  "node_version": "lts"
}
```

Config sources (in priority order):
1. `--config <path>` flag (local file or URL)
2. `--preset <name>` flag (built-in preset)
3. `bundledownload.json` in current directory (auto-detected)
4. Interactive picker (if none of the above)

---

## Install Methods Per Tool Per OS

### macOS

| Tool | Method |
|---|---|
| git | `brew install git` (or Xcode CLT) |
| node | `brew install fnm && fnm install --lts` |
| gh | `brew install gh` |
| gcloud | `brew install google-cloud-sdk` |
| az | `brew install azure-cli` |
| aws | Download PKG from AWS, run installer |
| vercel | `npm install -g vercel` |
| supabase | `brew install supabase/tap/supabase` |
| wrangler | `npm install -g wrangler` |
| claude-code | `curl -fsSL https://claude.ai/install.sh \| bash` |
| whisperflow | `brew install portaudio && pip install whisperflow` |
| tabby | `brew install --cask tabby` |

### Linux (Debian/Ubuntu)

| Tool | Method |
|---|---|
| git | `sudo apt-get install -y git` |
| node | Install fnm via curl, then `fnm install --lts` |
| gh | Add GitHub APT repo, `sudo apt-get install gh` |
| gcloud | Add Google Cloud APT repo, `sudo apt-get install google-cloud-cli` |
| az | Add Microsoft APT repo, `sudo apt-get install azure-cli` |
| aws | Download zip, run `./aws/install` |
| vercel | `npm install -g vercel` |
| supabase | Download binary from GitHub releases |
| wrangler | `npm install -g wrangler` |
| claude-code | `curl -fsSL https://claude.ai/install.sh \| bash` |
| whisperflow | `sudo apt-get install -y portaudio19-dev && pip install whisperflow` |
| tabby | Download .deb from GitHub releases, `sudo dpkg -i` |

### Windows

| Tool | Method |
|---|---|
| git | `winget install Git.Git` |
| node | `winget install Schniz.fnm` then `fnm install --lts` |
| gh | `winget install GitHub.cli` |
| gcloud | Download MSI installer, run silently |
| az | `winget install Microsoft.AzureCLI` |
| aws | Download MSI from AWS, run silently |
| vercel | `npm install -g vercel` |
| supabase | `scoop bucket add supabase ...; scoop install supabase` |
| wrangler | `npm install -g wrangler` |
| claude-code | `irm https://claude.ai/install.ps1 \| iex` |
| whisperflow | `pip install whisperflow` |
| tabby | `winget install Eugeny.Tabby` |

---

## File Structure

```
bundledownload/
├── install.sh              # Bash entry point (macOS + Linux)
├── install.ps1             # PowerShell entry point (Windows)
├── presets/
│   ├── dannys-stack.json
│   ├── frontend-dev.json
│   ├── cloud-ops.json
│   └── full-stack.json
├── lib/
│   ├── detect-os.sh        # OS/arch/package manager detection
│   ├── tools.sh             # Tool definitions (install commands, version checks)
│   ├── ui.sh                # Interactive picker, progress display
│   ├── detect-os.ps1
│   ├── tools.ps1
│   └── ui.ps1
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-03-27-bundledownload-design.md
└── README.md
```

**Note:** Since the scripts are downloaded via `curl | bash`, the entry point scripts must be self-contained OR download the lib files first. Approach: **single-file scripts** that embed everything. The `lib/` structure is for development organization — a build step concatenates them into the final `install.sh` and `install.ps1`.

---

## Output & UX

### Progress Display

```
 BundleDownload v1.0
 Detected: macOS 14.2 (arm64) — Homebrew available

 Installing dannys-stack (8 tools)...

 [✓] git 2.43.0 — already installed
 [✓] node 22.0.0 — installed via fnm (3s)
 [⠋] vercel — installing via npm...
 [⠋] wrangler — installing via npm...
 [ ] supabase — waiting...
 [ ] gh — queued (phase 3)
 [ ] claude-code — queued (phase 3)
 [ ] tabby — queued (phase 4)
```

### Completion Summary

```
 Done! 7 tools installed, 1 already present.

 Installed: node, vercel, wrangler, supabase, gh, claude-code, tabby
 Skipped:   git (already installed)

 Next steps:
   • Run `gh auth login` to authenticate with GitHub
   • Run `claude` to set up Claude Code
   • Run `vercel login` to connect your Vercel account
```

---

## Verification

1. **Test on macOS:** Run `install.sh` with `--preset dannys-stack`, verify all tools install and are on PATH
2. **Test on Windows:** Run `install.ps1` with `--preset dannys-stack` in PowerShell
3. **Test on Linux (Ubuntu):** Run in a Docker container or VM
4. **Test already-installed detection:** Run twice — second run should skip everything
5. **Test interactive picker:** Run without flags, verify arrow keys + space work
6. **Test config file:** Create a `bundledownload.json`, verify it auto-detects
7. **Test `--yes` flag:** Verify no prompts in non-interactive mode
