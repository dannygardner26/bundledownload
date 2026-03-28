# BundleDownload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform CLI tool that installs a curated set of developer tools with one command, supporting presets, interactive selection, and dependency-aware ordering.

**Architecture:** Two self-contained scripts (`install.sh` for macOS/Linux, `install.ps1` for Windows) built from modular source files via a simple concatenation build step. Each script detects the OS, resolves tool dependencies, and installs in parallel phases.

**Tech Stack:** Bash 4+, PowerShell 5.1+, ANSI escape codes for UI, JSON for presets/configs.

---

## File Map

| File | Responsibility |
|---|---|
| `src/sh/header.sh` | Shebang, version, color constants, utility functions |
| `src/sh/detect-os.sh` | OS/arch/package manager detection |
| `src/sh/tools.sh` | Tool registry: IDs, version checks, install commands per OS, dependencies, phases |
| `src/sh/presets.sh` | Built-in preset definitions + JSON config file loader |
| `src/sh/ui.sh` | Interactive picker (arrow keys, space toggle, shortcuts) + progress display |
| `src/sh/installer.sh` | Phase runner: dependency ordering, parallel execution, already-installed checks |
| `src/sh/main.sh` | Arg parsing, orchestration, entry point |
| `src/ps1/header.ps1` | Version, color helpers, utility functions |
| `src/ps1/detect-os.ps1` | Windows version + winget detection |
| `src/ps1/tools.ps1` | Tool registry for Windows |
| `src/ps1/presets.ps1` | Preset definitions + JSON config loader |
| `src/ps1/ui.ps1` | Interactive picker + progress display (PowerShell) |
| `src/ps1/installer.ps1` | Phase runner for Windows |
| `src/ps1/main.ps1` | Arg parsing, orchestration, entry point |
| `build.sh` | Concatenates `src/sh/*.sh` → `install.sh`, `src/ps1/*.ps1` → `install.ps1` |
| `presets/dannys-stack.json` | Preset config file |
| `presets/frontend-dev.json` | Preset config file |
| `presets/cloud-ops.json` | Preset config file |
| `presets/full-stack.json` | Preset config file |

---

### Task 1: Project Scaffolding + Build Script

**Files:**
- Create: `build.sh`
- Create: `src/sh/header.sh`
- Create: `src/ps1/header.ps1`
- Create: `.gitignore`

- [ ] **Step 1: Create `.gitignore`**

```gitignore
# Build outputs
install.sh
install.ps1

# OS
.DS_Store
Thumbs.db

# Superpowers
.superpowers/
```

- [ ] **Step 2: Create `build.sh`**

This concatenates source files in order into the final distributable scripts.

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building install.sh..."
cat \
  "$SCRIPT_DIR/src/sh/header.sh" \
  "$SCRIPT_DIR/src/sh/detect-os.sh" \
  "$SCRIPT_DIR/src/sh/tools.sh" \
  "$SCRIPT_DIR/src/sh/presets.sh" \
  "$SCRIPT_DIR/src/sh/ui.sh" \
  "$SCRIPT_DIR/src/sh/installer.sh" \
  "$SCRIPT_DIR/src/sh/main.sh" \
  > "$SCRIPT_DIR/install.sh"
chmod +x "$SCRIPT_DIR/install.sh"
echo "  -> install.sh ($(wc -c < "$SCRIPT_DIR/install.sh") bytes)"

echo "Building install.ps1..."
cat \
  "$SCRIPT_DIR/src/ps1/header.ps1" \
  "$SCRIPT_DIR/src/ps1/detect-os.ps1" \
  "$SCRIPT_DIR/src/ps1/tools.ps1" \
  "$SCRIPT_DIR/src/ps1/presets.ps1" \
  "$SCRIPT_DIR/src/ps1/ui.ps1" \
  "$SCRIPT_DIR/src/ps1/installer.ps1" \
  "$SCRIPT_DIR/src/ps1/main.ps1" \
  > "$SCRIPT_DIR/install.ps1"
echo "  -> install.ps1 ($(wc -c < "$SCRIPT_DIR/install.ps1") bytes)"

echo "Done."
```

- [ ] **Step 3: Create `src/sh/header.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

BUNDLEDOWNLOAD_VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# Spinner frames
SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

log_info()    { printf "${BLUE}[info]${RESET} %s\n" "$1"; }
log_success() { printf "${GREEN}[✓]${RESET} %s\n" "$1"; }
log_warn()    { printf "${YELLOW}[!]${RESET} %s\n" "$1"; }
log_error()   { printf "${RED}[✗]${RESET} %s\n" "$1"; }
log_skip()    { printf "${DIM}[skip]${RESET} %s\n" "$1"; }

command_exists() { command -v "$1" &>/dev/null; }
```

- [ ] **Step 4: Create `src/ps1/header.ps1`**

```powershell
#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$BUNDLEDOWNLOAD_VERSION = "1.0.0"

function Write-Info    { param([string]$Msg) Write-Host "[info] " -ForegroundColor Blue -NoNewline; Write-Host $Msg }
function Write-Success { param([string]$Msg) Write-Host "[✓] " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn    { param([string]$Msg) Write-Host "[!] " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Err     { param([string]$Msg) Write-Host "[✗] " -ForegroundColor Red -NoNewline; Write-Host $Msg }
function Write-Skip    { param([string]$Msg) Write-Host "[skip] " -ForegroundColor DarkGray -NoNewline; Write-Host $Msg }

function Test-CommandExists { param([string]$Cmd) return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue) }
```

- [ ] **Step 5: Run build and verify**

Run: `bash build.sh`
Expected: Both `install.sh` and `install.ps1` created with correct byte counts printed.

- [ ] **Step 6: Commit**

```bash
git add build.sh src/sh/header.sh src/ps1/header.ps1 .gitignore
git commit -m "feat: project scaffolding with build script and header modules"
```

---

### Task 2: OS Detection

**Files:**
- Create: `src/sh/detect-os.sh`
- Create: `src/ps1/detect-os.ps1`

- [ ] **Step 1: Create `src/sh/detect-os.sh`**

```bash
# OS Detection
# Sets: BD_OS (macos|linux), BD_ARCH (arm64|x86_64), BD_DISTRO (debian|fedora|arch|unknown), BD_PKG_MGR (brew|apt|dnf|pacman)

detect_os() {
  local uname_s
  uname_s="$(uname -s)"
  BD_ARCH="$(uname -m)"

  case "$uname_s" in
    Darwin)
      BD_OS="macos"
      BD_DISTRO="macos"
      BD_PKG_MGR="brew"
      ;;
    Linux)
      BD_OS="linux"
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
          ubuntu|debian|pop|mint|elementary) BD_DISTRO="debian"; BD_PKG_MGR="apt" ;;
          fedora|rhel|centos|rocky|alma)     BD_DISTRO="fedora"; BD_PKG_MGR="dnf" ;;
          arch|manjaro|endeavouros)          BD_DISTRO="arch";   BD_PKG_MGR="pacman" ;;
          *)                                 BD_DISTRO="unknown"; BD_PKG_MGR="unknown" ;;
        esac
      else
        BD_DISTRO="unknown"
        BD_PKG_MGR="unknown"
      fi
      ;;
    *)
      log_error "Unsupported OS: $uname_s"
      exit 1
      ;;
  esac
}

ensure_package_manager() {
  case "$BD_PKG_MGR" in
    brew)
      if ! command_exists brew; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add brew to PATH for Apple Silicon
        if [[ "$BD_ARCH" == "arm64" ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
      fi
      ;;
    apt)
      log_info "Updating apt package list..."
      sudo apt-get update -qq
      ;;
    dnf) ;; # dnf handles this automatically
    pacman)
      log_info "Updating pacman database..."
      sudo pacman -Sy --noconfirm
      ;;
    *)
      log_warn "Unknown package manager. Some tools may fail to install."
      ;;
  esac
}

print_system_info() {
  printf "\n${BOLD} BundleDownload v%s${RESET}\n" "$BUNDLEDOWNLOAD_VERSION"
  printf " ${DIM}Detected: %s %s (%s)" "$BD_OS" "$BD_DISTRO" "$BD_ARCH"
  if command_exists "$BD_PKG_MGR"; then
    printf " — %s available" "$BD_PKG_MGR"
  fi
  printf "${RESET}\n\n"
}
```

- [ ] **Step 2: Create `src/ps1/detect-os.ps1`**

```powershell
# OS Detection for Windows
# Sets: $script:BD_OS, $script:BD_ARCH, $script:BD_WINVER, $script:BD_HAS_WINGET, $script:BD_HAS_SCOOP

function Detect-OS {
    $script:BD_OS = "windows"
    $script:BD_ARCH = if ([System.Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $script:BD_WINVER = [System.Environment]::OSVersion.Version.ToString()
    $script:BD_HAS_WINGET = Test-CommandExists "winget"
    $script:BD_HAS_SCOOP = Test-CommandExists "scoop"
}

function Ensure-PackageManager {
    if (-not $script:BD_HAS_WINGET) {
        Write-Err "winget is not available. Please install App Installer from the Microsoft Store."
        Write-Err "https://aka.ms/getwinget"
        exit 1
    }
}

function Print-SystemInfo {
    Write-Host ""
    Write-Host " BundleDownload v$BUNDLEDOWNLOAD_VERSION" -ForegroundColor White
    Write-Host " Detected: Windows $($script:BD_WINVER) ($($script:BD_ARCH))" -NoNewline -ForegroundColor DarkGray
    if ($script:BD_HAS_WINGET) { Write-Host " — winget available" -ForegroundColor DarkGray -NoNewline }
    if ($script:BD_HAS_SCOOP)  { Write-Host " — scoop available" -ForegroundColor DarkGray -NoNewline }
    Write-Host "`n"
}
```

- [ ] **Step 3: Build and test OS detection**

Run: `bash build.sh`
Then test: `bash -c 'source install.sh; detect_os; print_system_info'` — but since `install.sh` will try to run main, we'll test this properly in Task 7 when main.sh exists. For now just verify the build succeeds.

- [ ] **Step 4: Commit**

```bash
git add src/sh/detect-os.sh src/ps1/detect-os.ps1
git commit -m "feat: OS detection for macOS, Linux, and Windows"
```

---

### Task 3: Tool Registry

**Files:**
- Create: `src/sh/tools.sh`
- Create: `src/ps1/tools.ps1`

- [ ] **Step 1: Create `src/sh/tools.sh`**

This defines every tool's metadata as bash functions/arrays. Each tool has: ID, display name, version command, phase, dependencies, and install commands per OS.

```bash
# Tool Registry
# Each tool is defined by a set of variables: TOOL_<ID>_*

# All tool IDs in display order
ALL_TOOL_IDS=(git node gh gcloud az aws vercel supabase wrangler claude-code whisperflow tabby)

# Phase assignments (1=foundations, 2=npm-tools, 3=standalone, 4=apps)
declare -A TOOL_PHASE=(
  [git]=1 [node]=1
  [vercel]=2 [wrangler]=2 [supabase]=2
  [gh]=3 [aws]=3 [az]=3 [gcloud]=3 [claude-code]=3
  [tabby]=4 [whisperflow]=4
)

# Dependencies (tool ID -> space-separated dependency IDs)
declare -A TOOL_DEPS=(
  [vercel]="node"
  [wrangler]="node"
)

# Display names
declare -A TOOL_NAME=(
  [git]="Git"
  [node]="Node.js (via fnm)"
  [gh]="GitHub CLI"
  [gcloud]="Google Cloud CLI"
  [az]="Azure CLI"
  [aws]="AWS CLI"
  [vercel]="Vercel CLI"
  [supabase]="Supabase CLI"
  [wrangler]="Cloudflare Wrangler"
  [claude-code]="Claude Code"
  [whisperflow]="WhisperFlow"
  [tabby]="Tabby Terminal"
)

# Version check commands
declare -A TOOL_VERSION_CMD=(
  [git]="git --version"
  [node]="node --version"
  [gh]="gh --version"
  [gcloud]="gcloud --version 2>/dev/null | head -1"
  [az]="az --version 2>/dev/null | head -1"
  [aws]="aws --version"
  [vercel]="vercel --version 2>/dev/null"
  [supabase]="supabase --version"
  [wrangler]="wrangler --version 2>/dev/null"
  [claude-code]="claude --version 2>/dev/null"
  [whisperflow]="whisperflow --version 2>/dev/null"
  [tabby]=""
)

# Check if tool is already installed. Returns 0 if installed, 1 if not.
# Prints version string if installed.
tool_check_installed() {
  local id="$1"
  local cmd="${TOOL_VERSION_CMD[$id]}"
  if [[ -z "$cmd" ]]; then
    # Desktop apps — check common locations
    case "$id" in
      tabby)
        case "$BD_OS" in
          macos)  [[ -d "/Applications/Tabby.app" ]] && echo "installed" && return 0 ;;
          linux)  command_exists tabby && echo "installed" && return 0 ;;
        esac
        ;;
    esac
    return 1
  fi
  local version
  version=$(eval "$cmd" 2>/dev/null) && echo "$version" && return 0
  return 1
}

# Install a single tool. Expects BD_OS, BD_DISTRO, BD_PKG_MGR to be set.
tool_install() {
  local id="$1"
  case "$id" in
    git)
      case "$BD_PKG_MGR" in
        brew)   brew install git ;;
        apt)    sudo apt-get install -y git ;;
        dnf)    sudo dnf install -y git ;;
        pacman) sudo pacman -S --noconfirm git ;;
      esac
      ;;
    node)
      case "$BD_OS" in
        macos)
          brew install fnm
          ;;
        linux)
          curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
          export PATH="$HOME/.local/share/fnm:$PATH"
          ;;
      esac
      eval "$(fnm env)"
      fnm install --lts
      fnm default lts-latest
      ;;
    gh)
      case "$BD_PKG_MGR" in
        brew)   brew install gh ;;
        apt)
          sudo mkdir -p -m 755 /etc/apt/keyrings
          curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
          echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
          sudo apt-get update -qq && sudo apt-get install -y gh
          ;;
        dnf)    sudo dnf install -y gh ;;
        pacman) sudo pacman -S --noconfirm github-cli ;;
      esac
      ;;
    gcloud)
      case "$BD_PKG_MGR" in
        brew) brew install google-cloud-sdk ;;
        apt)
          curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
          echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null
          sudo apt-get update -qq && sudo apt-get install -y google-cloud-cli
          ;;
        dnf) sudo dnf install -y google-cloud-cli ;;
        *)   curl https://sdk.cloud.google.com | bash -s -- --disable-prompts ;;
      esac
      ;;
    az)
      case "$BD_PKG_MGR" in
        brew) brew install azure-cli ;;
        apt)  curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash ;;
        dnf)  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc && sudo dnf install -y azure-cli ;;
        *)    curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash ;;
      esac
      ;;
    aws)
      case "$BD_OS" in
        macos)
          curl -fsSL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o /tmp/AWSCLIV2.pkg
          sudo installer -pkg /tmp/AWSCLIV2.pkg -target /
          rm -f /tmp/AWSCLIV2.pkg
          ;;
        linux)
          curl -fsSL "https://awscli.amazonaws.com/awscliv2-linux-$(uname -m).zip" -o /tmp/awscliv2.zip
          unzip -qo /tmp/awscliv2.zip -d /tmp/aws-install
          sudo /tmp/aws-install/aws/install --update
          rm -rf /tmp/awscliv2.zip /tmp/aws-install
          ;;
      esac
      ;;
    vercel)
      npm install -g vercel
      ;;
    supabase)
      case "$BD_PKG_MGR" in
        brew) brew install supabase/tap/supabase ;;
        *)
          local latest
          latest=$(curl -fsSL https://api.github.com/repos/supabase/cli/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
          curl -fsSL "https://github.com/supabase/cli/releases/download/v${latest}/supabase_linux_$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/').tar.gz" | sudo tar -xz -C /usr/local/bin supabase
          ;;
      esac
      ;;
    wrangler)
      npm install -g wrangler
      ;;
    claude-code)
      curl -fsSL https://claude.ai/install.sh | bash
      ;;
    whisperflow)
      case "$BD_PKG_MGR" in
        brew)   brew install portaudio && pip3 install whisperflow ;;
        apt)    sudo apt-get install -y portaudio19-dev && pip3 install whisperflow ;;
        dnf)    sudo dnf install -y portaudio-devel && pip3 install whisperflow ;;
        pacman) sudo pacman -S --noconfirm portaudio && pip3 install whisperflow ;;
      esac
      ;;
    tabby)
      case "$BD_PKG_MGR" in
        brew) brew install --cask tabby ;;
        *)
          local latest
          latest=$(curl -fsSL https://api.github.com/repos/Eugeny/tabby/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
          local arch_suffix
          arch_suffix=$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')
          curl -fsSL "https://github.com/Eugeny/tabby/releases/download/v${latest}/tabby-${latest}-linux-${arch_suffix}.deb" -o /tmp/tabby.deb
          sudo dpkg -i /tmp/tabby.deb || sudo apt-get install -f -y
          rm -f /tmp/tabby.deb
          ;;
      esac
      ;;
    *)
      log_error "Unknown tool: $id"
      return 1
      ;;
  esac
}
```

- [ ] **Step 2: Create `src/ps1/tools.ps1`**

```powershell
# Tool Registry for Windows

$ALL_TOOL_IDS = @("git", "node", "gh", "gcloud", "az", "aws", "vercel", "supabase", "wrangler", "claude-code", "whisperflow", "tabby")

$TOOL_PHASE = @{
    "git" = 1; "node" = 1
    "vercel" = 2; "wrangler" = 2; "supabase" = 2
    "gh" = 3; "aws" = 3; "az" = 3; "gcloud" = 3; "claude-code" = 3
    "tabby" = 4; "whisperflow" = 4
}

$TOOL_DEPS = @{
    "vercel"  = @("node")
    "wrangler" = @("node")
}

$TOOL_NAME = @{
    "git" = "Git"; "node" = "Node.js (via fnm)"; "gh" = "GitHub CLI"
    "gcloud" = "Google Cloud CLI"; "az" = "Azure CLI"; "aws" = "AWS CLI"
    "vercel" = "Vercel CLI"; "supabase" = "Supabase CLI"; "wrangler" = "Cloudflare Wrangler"
    "claude-code" = "Claude Code"; "whisperflow" = "WhisperFlow"; "tabby" = "Tabby Terminal"
}

$TOOL_VERSION_CMD = @{
    "git" = "git --version"; "node" = "node --version"; "gh" = "gh --version"
    "gcloud" = "gcloud --version 2>`$null | Select-Object -First 1"
    "az" = "az --version 2>`$null | Select-Object -First 1"
    "aws" = "aws --version"; "vercel" = "vercel --version 2>`$null"
    "supabase" = "supabase --version"; "wrangler" = "wrangler --version 2>`$null"
    "claude-code" = "claude --version 2>`$null"
    "whisperflow" = "whisperflow --version 2>`$null"
    "tabby" = ""
}

function Test-ToolInstalled {
    param([string]$Id)
    $cmd = $TOOL_VERSION_CMD[$Id]
    if ([string]::IsNullOrEmpty($cmd)) {
        # Desktop apps
        switch ($Id) {
            "tabby" {
                $paths = @(
                    "$env:LOCALAPPDATA\Programs\Tabby\Tabby.exe",
                    "$env:ProgramFiles\Tabby\Tabby.exe"
                )
                foreach ($p in $paths) { if (Test-Path $p) { return "installed" } }
                return $null
            }
        }
        return $null
    }
    try {
        $result = Invoke-Expression $cmd 2>$null
        if ($LASTEXITCODE -eq 0 -or $result) { return $result }
    } catch {}
    return $null
}

function Install-Tool {
    param([string]$Id)
    switch ($Id) {
        "git"         { winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements }
        "node"        {
            winget install --id Schniz.fnm -e --accept-source-agreements --accept-package-agreements
            $env:PATH = "$env:LOCALAPPDATA\fnm;$env:PATH"
            fnm env --use-on-cd | Out-String | Invoke-Expression
            fnm install --lts
            fnm default lts-latest
        }
        "gh"          { winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements }
        "gcloud"      {
            $installer = "$env:TEMP\google-cloud-sdk-installer.exe"
            Invoke-WebRequest -Uri "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe" -OutFile $installer
            Start-Process -FilePath $installer -ArgumentList "/S" -Wait
            Remove-Item $installer -Force
        }
        "az"          { winget install --id Microsoft.AzureCLI -e --accept-source-agreements --accept-package-agreements }
        "aws"         {
            $msi = "$env:TEMP\AWSCLIV2.msi"
            Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $msi
            Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn" -Wait
            Remove-Item $msi -Force
        }
        "vercel"      { npm install -g vercel }
        "supabase"    {
            if ($script:BD_HAS_SCOOP) {
                scoop bucket add supabase https://github.com/supabase/scoop-bucket.git 2>$null
                scoop install supabase
            } else {
                npm install -g supabase
            }
        }
        "wrangler"    { npm install -g wrangler }
        "claude-code" { Invoke-Expression "& { $(Invoke-RestMethod https://claude.ai/install.ps1) }" }
        "whisperflow" { pip install whisperflow }
        "tabby"       { winget install --id Eugeny.Tabby -e --accept-source-agreements --accept-package-agreements }
        default       { Write-Err "Unknown tool: $Id"; return $false }
    }
    return $true
}
```

- [ ] **Step 3: Build and verify**

Run: `bash build.sh`
Expected: Successful build, files now contain header + detect-os + tools sections.

- [ ] **Step 4: Commit**

```bash
git add src/sh/tools.sh src/ps1/tools.ps1
git commit -m "feat: tool registry with install commands for all 12 tools across all platforms"
```

---

### Task 4: Preset System

**Files:**
- Create: `src/sh/presets.sh`
- Create: `src/ps1/presets.ps1`
- Create: `presets/dannys-stack.json`
- Create: `presets/frontend-dev.json`
- Create: `presets/cloud-ops.json`
- Create: `presets/full-stack.json`

- [ ] **Step 1: Create preset JSON files**

`presets/dannys-stack.json`:
```json
{
  "name": "dannys-stack",
  "description": "Danny's preferred developer tools",
  "tools": ["node", "git", "gh", "claude-code", "vercel", "supabase", "wrangler", "tabby"]
}
```

`presets/frontend-dev.json`:
```json
{
  "name": "frontend-dev",
  "description": "Frontend development essentials",
  "tools": ["node", "git", "gh", "vercel", "wrangler"]
}
```

`presets/cloud-ops.json`:
```json
{
  "name": "cloud-ops",
  "description": "Cloud platform CLIs",
  "tools": ["git", "gh", "aws", "az", "gcloud"]
}
```

`presets/full-stack.json`:
```json
{
  "name": "full-stack",
  "description": "Everything",
  "tools": ["git", "node", "gh", "gcloud", "az", "aws", "vercel", "supabase", "wrangler", "claude-code", "whisperflow", "tabby"]
}
```

- [ ] **Step 2: Create `src/sh/presets.sh`**

```bash
# Preset System

# Built-in presets (embedded so curl|bash works without extra downloads)
declare -A BUILTIN_PRESETS=(
  [dannys-stack]="node git gh claude-code vercel supabase wrangler tabby"
  [frontend-dev]="node git gh vercel wrangler"
  [cloud-ops]="git gh aws az gcloud"
  [full-stack]="git node gh gcloud az aws vercel supabase wrangler claude-code whisperflow tabby"
)

BUILTIN_PRESET_NAMES=("dannys-stack" "frontend-dev" "cloud-ops" "full-stack")

# Load tools from a preset name or config file.
# Sets SELECTED_TOOLS array.
load_preset() {
  local name="$1"
  if [[ -n "${BUILTIN_PRESETS[$name]+x}" ]]; then
    IFS=' ' read -ra SELECTED_TOOLS <<< "${BUILTIN_PRESETS[$name]}"
    log_info "Loaded preset: $name (${#SELECTED_TOOLS[@]} tools)"
    return 0
  fi
  log_error "Unknown preset: $name"
  log_info "Available presets: ${BUILTIN_PRESET_NAMES[*]}"
  return 1
}

# Load tools from a JSON config file (local path or URL).
# Requires: python3 or jq for JSON parsing.
load_config_file() {
  local path="$1"
  local json

  # Handle URLs
  if [[ "$path" == http://* ]] || [[ "$path" == https://* ]]; then
    json=$(curl -fsSL "$path")
  elif [[ -f "$path" ]]; then
    json=$(cat "$path")
  else
    log_error "Config file not found: $path"
    return 1
  fi

  # Parse JSON — try jq first, fall back to python3
  local tools_str
  if command_exists jq; then
    tools_str=$(echo "$json" | jq -r '.tools[]' 2>/dev/null | tr '\n' ' ')
  elif command_exists python3; then
    tools_str=$(echo "$json" | python3 -c "import sys,json; print(' '.join(json.load(sys.stdin)['tools']))" 2>/dev/null)
  else
    log_error "Need jq or python3 to parse JSON config files"
    return 1
  fi

  IFS=' ' read -ra SELECTED_TOOLS <<< "$tools_str"
  local config_name
  if command_exists jq; then
    config_name=$(echo "$json" | jq -r '.name // "custom"')
  else
    config_name="custom"
  fi
  log_info "Loaded config: $config_name (${#SELECTED_TOOLS[@]} tools)"
  return 0
}

# Auto-detect bundledownload.json in current directory
auto_detect_config() {
  if [[ -f "bundledownload.json" ]]; then
    log_info "Found bundledownload.json in current directory"
    load_config_file "bundledownload.json"
    return $?
  fi
  return 1
}
```

- [ ] **Step 3: Create `src/ps1/presets.ps1`**

```powershell
# Preset System

$BUILTIN_PRESETS = @{
    "dannys-stack" = @("node", "git", "gh", "claude-code", "vercel", "supabase", "wrangler", "tabby")
    "frontend-dev" = @("node", "git", "gh", "vercel", "wrangler")
    "cloud-ops"    = @("git", "gh", "aws", "az", "gcloud")
    "full-stack"   = @("git", "node", "gh", "gcloud", "az", "aws", "vercel", "supabase", "wrangler", "claude-code", "whisperflow", "tabby")
}

$script:SELECTED_TOOLS = @()

function Load-Preset {
    param([string]$Name)
    if ($BUILTIN_PRESETS.ContainsKey($Name)) {
        $script:SELECTED_TOOLS = $BUILTIN_PRESETS[$Name]
        Write-Info "Loaded preset: $Name ($($script:SELECTED_TOOLS.Count) tools)"
        return $true
    }
    Write-Err "Unknown preset: $Name"
    Write-Info "Available presets: $($BUILTIN_PRESETS.Keys -join ', ')"
    return $false
}

function Load-ConfigFile {
    param([string]$Path)
    try {
        $json = if ($Path -match '^https?://') {
            (Invoke-RestMethod -Uri $Path)
        } elseif (Test-Path $Path) {
            Get-Content $Path -Raw | ConvertFrom-Json
        } else {
            Write-Err "Config file not found: $Path"
            return $false
        }
        $script:SELECTED_TOOLS = @($json.tools)
        $name = if ($json.name) { $json.name } else { "custom" }
        Write-Info "Loaded config: $name ($($script:SELECTED_TOOLS.Count) tools)"
        return $true
    } catch {
        Write-Err "Failed to parse config: $_"
        return $false
    }
}

function Auto-DetectConfig {
    if (Test-Path "bundledownload.json") {
        Write-Info "Found bundledownload.json in current directory"
        return Load-ConfigFile "bundledownload.json"
    }
    return $false
}
```

- [ ] **Step 4: Build and verify**

Run: `bash build.sh`

- [ ] **Step 5: Commit**

```bash
git add src/sh/presets.sh src/ps1/presets.ps1 presets/
git commit -m "feat: preset system with 4 built-in presets and JSON config file support"
```

---

### Task 5: Interactive UI (Picker + Progress)

**Files:**
- Create: `src/sh/ui.sh`
- Create: `src/ps1/ui.ps1`

- [ ] **Step 1: Create `src/sh/ui.sh`**

```bash
# Interactive UI — tool picker and progress display

# Interactive tool picker using ANSI escape codes
# Sets SELECTED_TOOLS array based on user selection
interactive_picker() {
  local cursor=0
  local -a selected=()
  local -a tool_ids=("${ALL_TOOL_IDS[@]}")
  local count=${#tool_ids[@]}

  # Pre-select dannys-stack by default
  local -A preselected
  for t in ${BUILTIN_PRESETS[dannys-stack]}; do
    preselected[$t]=1
  done

  # Initialize selection state
  local -a is_selected=()
  for ((i=0; i<count; i++)); do
    local id="${tool_ids[$i]}"
    if [[ -n "${preselected[$id]+x}" ]]; then
      is_selected+=("1")
    else
      is_selected+=("0")
    fi
  done

  # Hide cursor
  printf '\033[?25l'
  # Cleanup on exit
  trap 'printf "\033[?25h"' EXIT

  printf "${BOLD} Select tools to install${RESET}\n"
  printf " ${DIM}↑/↓ = move  Space = toggle  a = all  n = none  Enter = install${RESET}\n\n"

  # Draw initial list
  draw_picker() {
    # Move cursor up to redraw
    if [[ ${1:-0} -eq 1 ]]; then
      printf "\033[%dA" "$count"
    fi
    for ((i=0; i<count; i++)); do
      local id="${tool_ids[$i]}"
      local name="${TOOL_NAME[$id]}"
      local marker=" "
      local color="$WHITE"
      if [[ "${is_selected[$i]}" == "1" ]]; then
        marker="✓"
        color="$CYAN"
      fi
      if [[ $i -eq $cursor ]]; then
        printf " ${color}❯ [%s] %s${RESET}\n" "$marker" "$name"
      else
        printf "   ${DIM}[%s]${RESET} %s\n" "$marker" "$name"
      fi
    done
  }

  draw_picker 0

  while true; do
    # Read a single keypress
    IFS= read -rsn1 key
    case "$key" in
      $'\x1b')
        read -rsn2 key
        case "$key" in
          '[A') # Up arrow
            ((cursor > 0)) && ((cursor--))
            ;;
          '[B') # Down arrow
            ((cursor < count - 1)) && ((cursor++))
            ;;
        esac
        ;;
      ' ') # Space — toggle
        if [[ "${is_selected[$cursor]}" == "1" ]]; then
          is_selected[$cursor]="0"
        else
          is_selected[$cursor]="1"
        fi
        ;;
      'a') # Select all
        for ((i=0; i<count; i++)); do is_selected[$i]="1"; done
        ;;
      'n') # Select none
        for ((i=0; i<count; i++)); do is_selected[$i]="0"; done
        ;;
      'p') # Preset submenu
        printf "\033[%dB" "$((count - cursor))"
        printf "\n ${BOLD}Presets:${RESET}\n"
        for ((pi=0; pi<${#BUILTIN_PRESET_NAMES[@]}; pi++)); do
          printf "  ${CYAN}%d)${RESET} %s\n" "$((pi+1))" "${BUILTIN_PRESET_NAMES[$pi]}"
        done
        printf " ${DIM}Enter number: ${RESET}"
        read -rn1 pkey
        printf "\n"
        if [[ "$pkey" =~ [1-4] ]]; then
          local pname="${BUILTIN_PRESET_NAMES[$((pkey-1))]}"
          local -A ptools
          for t in ${BUILTIN_PRESETS[$pname]}; do ptools[$t]=1; done
          for ((i=0; i<count; i++)); do
            local id="${tool_ids[$i]}"
            if [[ -n "${ptools[$id]+x}" ]]; then
              is_selected[$i]="1"
            else
              is_selected[$i]="0"
            fi
          done
        fi
        # Redraw header
        printf "\033[2K"
        printf "\033[%dA" "$((count + ${#BUILTIN_PRESET_NAMES[@]} + 4))"
        for ((i=0; i<$(( ${#BUILTIN_PRESET_NAMES[@]} + 4 )); i++)); do
          printf "\033[2K\n"
        done
        printf "\033[%dA" "$((${#BUILTIN_PRESET_NAMES[@]} + 4))"
        draw_picker 0
        continue
        ;;
      '') # Enter — confirm
        break
        ;;
    esac
    draw_picker 1
  done

  # Show cursor again
  printf '\033[?25h'
  trap - EXIT

  # Build SELECTED_TOOLS from selection
  SELECTED_TOOLS=()
  for ((i=0; i<count; i++)); do
    if [[ "${is_selected[$i]}" == "1" ]]; then
      SELECTED_TOOLS+=("${tool_ids[$i]}")
    fi
  done

  if [[ ${#SELECTED_TOOLS[@]} -eq 0 ]]; then
    log_warn "No tools selected. Exiting."
    exit 0
  fi

  printf "\n ${BOLD}%d tools selected${RESET}\n\n" "${#SELECTED_TOOLS[@]}"
}

# Progress display during installation
# Usage: progress_start "tool-id" / progress_done "tool-id" "version" / progress_fail "tool-id" "error"

declare -A TOOL_STATUS=()
declare -A TOOL_STATUS_MSG=()

progress_start() {
  local id="$1"
  TOOL_STATUS[$id]="installing"
  TOOL_STATUS_MSG[$id]="installing..."
  printf " ${YELLOW}[⠋]${RESET} %s — installing...\n" "${TOOL_NAME[$id]}"
}

progress_done() {
  local id="$1"
  local version="${2:-installed}"
  TOOL_STATUS[$id]="done"
  # Move up and overwrite
  printf "\033[1A\033[2K"
  printf " ${GREEN}[✓]${RESET} %s — %s\n" "${TOOL_NAME[$id]}" "$version"
}

progress_skip() {
  local id="$1"
  local version="$2"
  TOOL_STATUS[$id]="skip"
  printf " ${GREEN}[✓]${RESET} %s %s — ${DIM}already installed${RESET}\n" "${TOOL_NAME[$id]}" "$version"
}

progress_fail() {
  local id="$1"
  local err="${2:-failed}"
  TOOL_STATUS[$id]="fail"
  printf "\033[1A\033[2K"
  printf " ${RED}[✗]${RESET} %s — %s\n" "${TOOL_NAME[$id]}" "$err"
}
```

- [ ] **Step 2: Create `src/ps1/ui.ps1`**

```powershell
# Interactive UI for Windows

function Show-InteractivePicker {
    $cursor = 0
    $toolIds = $ALL_TOOL_IDS
    $count = $toolIds.Count

    # Pre-select dannys-stack
    $preselected = @{}
    foreach ($t in $BUILTIN_PRESETS["dannys-stack"]) { $preselected[$t] = $true }

    $isSelected = @()
    foreach ($id in $toolIds) {
        $isSelected += if ($preselected.ContainsKey($id)) { $true } else { $false }
    }

    [Console]::CursorVisible = $false

    Write-Host " Select tools to install" -ForegroundColor White
    Write-Host " Up/Down = move  Space = toggle  a = all  n = none  Enter = install" -ForegroundColor DarkGray
    Write-Host ""

    $listTop = [Console]::CursorTop

    function Draw-List {
        [Console]::SetCursorPosition(0, $listTop)
        for ($i = 0; $i -lt $count; $i++) {
            $id = $toolIds[$i]
            $name = $TOOL_NAME[$id]
            $marker = if ($isSelected[$i]) { "x" } else { " " }
            $prefix = if ($i -eq $cursor) { ">" } else { " " }
            $color = if ($isSelected[$i]) { "Cyan" } else { "Gray" }

            Write-Host ("  {0} [{1}] {2}" -f $prefix, $marker, $name).PadRight(60) -ForegroundColor $color
        }
    }

    Draw-List

    while ($true) {
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { if ($cursor -gt 0) { $cursor-- } }
            "DownArrow" { if ($cursor -lt ($count - 1)) { $cursor++ } }
            "Spacebar"  { $isSelected[$cursor] = -not $isSelected[$cursor] }
            "A"         { for ($i = 0; $i -lt $count; $i++) { $isSelected[$i] = $true } }
            "N"         { for ($i = 0; $i -lt $count; $i++) { $isSelected[$i] = $false } }
            "Enter"     { break }
        }
        Draw-List
    }

    [Console]::CursorVisible = $true

    $script:SELECTED_TOOLS = @()
    for ($i = 0; $i -lt $count; $i++) {
        if ($isSelected[$i]) { $script:SELECTED_TOOLS += $toolIds[$i] }
    }

    if ($script:SELECTED_TOOLS.Count -eq 0) {
        Write-Warn "No tools selected. Exiting."
        exit 0
    }

    Write-Host "`n $($script:SELECTED_TOOLS.Count) tools selected`n" -ForegroundColor White
}

function Write-ProgressStart {
    param([string]$Id)
    Write-Host " [..] $($TOOL_NAME[$Id]) — installing..." -ForegroundColor Yellow
}

function Write-ProgressDone {
    param([string]$Id, [string]$Version = "installed")
    # Overwrite previous line
    [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
    Write-Host (" [ok] {0} — {1}" -f $TOOL_NAME[$Id], $Version).PadRight(60) -ForegroundColor Green
}

function Write-ProgressSkip {
    param([string]$Id, [string]$Version)
    Write-Host " [ok] $($TOOL_NAME[$Id]) $Version — already installed" -ForegroundColor Green
}

function Write-ProgressFail {
    param([string]$Id, [string]$Err = "failed")
    [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
    Write-Host (" [!!] {0} — {1}" -f $TOOL_NAME[$Id], $Err).PadRight(60) -ForegroundColor Red
}
```

- [ ] **Step 3: Build and verify**

Run: `bash build.sh`

- [ ] **Step 4: Commit**

```bash
git add src/sh/ui.sh src/ps1/ui.ps1
git commit -m "feat: interactive tool picker and progress display for bash and PowerShell"
```

---

### Task 6: Installer Engine (Phase Runner)

**Files:**
- Create: `src/sh/installer.sh`
- Create: `src/ps1/installer.ps1`

- [ ] **Step 1: Create `src/sh/installer.sh`**

```bash
# Installer Engine — runs tools in dependency-aware phases

run_install() {
  local -a tools=("${SELECTED_TOOLS[@]}")
  local total=${#tools[@]}
  local installed=0
  local skipped=0
  local failed=0
  local -a failed_tools=()
  local -a installed_tools=()
  local -a skipped_tools=()
  local -a next_steps=()

  # Group tools by phase
  local -a phase1=() phase2=() phase3=() phase4=()
  for id in "${tools[@]}"; do
    case "${TOOL_PHASE[$id]}" in
      1) phase1+=("$id") ;;
      2) phase2+=("$id") ;;
      3) phase3+=("$id") ;;
      4) phase4+=("$id") ;;
    esac
  done

  printf " ${BOLD}Installing %d tools...${RESET}\n\n" "$total"

  # Install a single tool with status reporting
  install_one() {
    local id="$1"
    local version
    if version=$(tool_check_installed "$id"); then
      progress_skip "$id" "$version"
      ((skipped++))
      skipped_tools+=("$id")
      return 0
    fi

    progress_start "$id"
    if tool_install "$id" >/dev/null 2>&1; then
      version=$(tool_check_installed "$id" 2>/dev/null) || version="installed"
      progress_done "$id" "$version"
      ((installed++))
      installed_tools+=("$id")

      # Collect next steps
      case "$id" in
        gh)          next_steps+=("Run \`gh auth login\` to authenticate with GitHub") ;;
        claude-code) next_steps+=("Run \`claude\` to set up Claude Code") ;;
        vercel)      next_steps+=("Run \`vercel login\` to connect your Vercel account") ;;
        gcloud)      next_steps+=("Run \`gcloud init\` to configure Google Cloud") ;;
        az)          next_steps+=("Run \`az login\` to authenticate with Azure") ;;
        aws)         next_steps+=("Run \`aws configure\` to set up AWS credentials") ;;
        supabase)    next_steps+=("Run \`supabase login\` to authenticate with Supabase") ;;
        wrangler)    next_steps+=("Run \`wrangler login\` to authenticate with Cloudflare") ;;
      esac
    else
      progress_fail "$id" "installation failed"
      ((failed++))
      failed_tools+=("$id")
    fi
  }

  # Run phases sequentially; within each phase, run tools sequentially
  # (parallel bg jobs add complexity — keep v1 simple and reliable)
  local -a phases=()
  [[ ${#phase1[@]} -gt 0 ]] && phases+=("1")
  [[ ${#phase2[@]} -gt 0 ]] && phases+=("2")
  [[ ${#phase3[@]} -gt 0 ]] && phases+=("3")
  [[ ${#phase4[@]} -gt 0 ]] && phases+=("4")

  for phase in "${phases[@]}"; do
    local -n phase_tools="phase${phase}"
    for id in "${phase_tools[@]}"; do
      install_one "$id"
    done
  done

  # Summary
  printf "\n${BOLD} Done!${RESET} %d installed, %d already present" "$installed" "$skipped"
  if [[ $failed -gt 0 ]]; then
    printf ", ${RED}%d failed${RESET}" "$failed"
  fi
  printf "\n\n"

  if [[ ${#installed_tools[@]} -gt 0 ]]; then
    printf " ${GREEN}Installed:${RESET} %s\n" "${installed_tools[*]}"
  fi
  if [[ ${#skipped_tools[@]} -gt 0 ]]; then
    printf " ${DIM}Skipped:${RESET}   %s\n" "${skipped_tools[*]}"
  fi
  if [[ ${#failed_tools[@]} -gt 0 ]]; then
    printf " ${RED}Failed:${RESET}    %s\n" "${failed_tools[*]}"
  fi

  if [[ ${#next_steps[@]} -gt 0 ]]; then
    printf "\n ${BOLD}Next steps:${RESET}\n"
    for step in "${next_steps[@]}"; do
      printf "   • %s\n" "$step"
    done
  fi
  printf "\n"

  # Exit code
  [[ $failed -eq 0 ]]
}
```

- [ ] **Step 2: Create `src/ps1/installer.ps1`**

```powershell
# Installer Engine for Windows

function Run-Install {
    $tools = $script:SELECTED_TOOLS
    $total = $tools.Count
    $installed = 0
    $skipped = 0
    $failed = 0
    $failedTools = @()
    $installedTools = @()
    $skippedTools = @()
    $nextSteps = @()

    # Group by phase
    $phases = @{ 1 = @(); 2 = @(); 3 = @(); 4 = @() }
    foreach ($id in $tools) {
        $phase = $TOOL_PHASE[$id]
        $phases[$phase] += $id
    }

    Write-Host " Installing $total tools...`n" -ForegroundColor White

    foreach ($phaseNum in (1..4)) {
        foreach ($id in $phases[$phaseNum]) {
            $version = Test-ToolInstalled $id
            if ($version) {
                Write-ProgressSkip $id $version
                $skipped++
                $skippedTools += $id
                continue
            }

            Write-ProgressStart $id
            try {
                $result = Install-Tool $id
                $version = Test-ToolInstalled $id
                if (-not $version) { $version = "installed" }
                Write-ProgressDone $id $version
                $installed++
                $installedTools += $id

                switch ($id) {
                    "gh"          { $nextSteps += "Run ``gh auth login`` to authenticate with GitHub" }
                    "claude-code" { $nextSteps += "Run ``claude`` to set up Claude Code" }
                    "vercel"      { $nextSteps += "Run ``vercel login`` to connect your Vercel account" }
                    "gcloud"      { $nextSteps += "Run ``gcloud init`` to configure Google Cloud" }
                    "az"          { $nextSteps += "Run ``az login`` to authenticate with Azure" }
                    "aws"         { $nextSteps += "Run ``aws configure`` to set up AWS credentials" }
                    "supabase"    { $nextSteps += "Run ``supabase login`` to authenticate with Supabase" }
                    "wrangler"    { $nextSteps += "Run ``wrangler login`` to authenticate with Cloudflare" }
                }
            } catch {
                Write-ProgressFail $id $_.Exception.Message
                $failed++
                $failedTools += $id
            }
        }
    }

    # Summary
    Write-Host ""
    $summary = " Done! $installed installed, $skipped already present"
    if ($failed -gt 0) { $summary += ", $failed failed" }
    Write-Host $summary -ForegroundColor White
    Write-Host ""

    if ($installedTools.Count -gt 0) { Write-Host " Installed: $($installedTools -join ', ')" -ForegroundColor Green }
    if ($skippedTools.Count -gt 0)   { Write-Host " Skipped:   $($skippedTools -join ', ')" -ForegroundColor DarkGray }
    if ($failedTools.Count -gt 0)    { Write-Host " Failed:    $($failedTools -join ', ')" -ForegroundColor Red }

    if ($nextSteps.Count -gt 0) {
        Write-Host "`n Next steps:" -ForegroundColor White
        foreach ($step in $nextSteps) {
            Write-Host "   * $step"
        }
    }
    Write-Host ""

    if ($failed -gt 0) { exit 1 }
}
```

- [ ] **Step 3: Build and verify**

Run: `bash build.sh`

- [ ] **Step 4: Commit**

```bash
git add src/sh/installer.sh src/ps1/installer.ps1
git commit -m "feat: phase-based installer engine with progress display and summary"
```

---

### Task 7: Main Entry Point + Arg Parsing

**Files:**
- Create: `src/sh/main.sh`
- Create: `src/ps1/main.ps1`

- [ ] **Step 1: Create `src/sh/main.sh`**

```bash
# Main entry point

usage() {
  cat <<EOF
BundleDownload v${BUNDLEDOWNLOAD_VERSION} — One-command developer tool installer

Usage:
  install.sh [options]

Options:
  --preset <name>    Use a built-in preset (dannys-stack, frontend-dev, cloud-ops, full-stack)
  --config <path>    Load tools from a JSON config file (local path or URL)
  --yes              Skip interactive prompts, install immediately
  --list             List available presets and exit
  --help             Show this help message

Examples:
  curl -fsSL https://bundledownload.dev/install.sh | bash
  curl -fsSL https://bundledownload.dev/install.sh | bash -s -- --preset dannys-stack
  curl -fsSL https://bundledownload.dev/install.sh | bash -s -- --config ./team-tools.json --yes
EOF
}

main() {
  local preset=""
  local config=""
  local auto_yes=0
  local list_presets=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --preset)  preset="$2"; shift 2 ;;
      --config)  config="$2"; shift 2 ;;
      --yes|-y)  auto_yes=1; shift ;;
      --list)    list_presets=1; shift ;;
      --help|-h) usage; exit 0 ;;
      *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done

  # Detect OS
  detect_os
  ensure_package_manager
  print_system_info

  # List presets
  if [[ $list_presets -eq 1 ]]; then
    printf " ${BOLD}Available presets:${RESET}\n\n"
    for name in "${BUILTIN_PRESET_NAMES[@]}"; do
      printf "  ${CYAN}%s${RESET}\n    %s\n\n" "$name" "${BUILTIN_PRESETS[$name]}"
    done
    exit 0
  fi

  # Load tool selection
  if [[ -n "$config" ]]; then
    load_config_file "$config" || exit 1
  elif [[ -n "$preset" ]]; then
    load_preset "$preset" || exit 1
  elif auto_detect_config; then
    : # Config loaded from bundledownload.json
  elif [[ $auto_yes -eq 1 ]]; then
    log_error "No preset or config specified with --yes. Use --preset or --config."
    exit 1
  else
    interactive_picker
  fi

  # Confirm if not --yes
  if [[ $auto_yes -eq 0 ]] && [[ -n "$preset" || -n "$config" ]]; then
    printf " Tools to install: ${CYAN}%s${RESET}\n" "${SELECTED_TOOLS[*]}"
    printf " ${DIM}Press Enter to continue, Ctrl+C to cancel...${RESET}"
    read -r
    printf "\n"
  fi

  # Run installation
  run_install
}

main "$@"
```

- [ ] **Step 2: Create `src/ps1/main.ps1`**

```powershell
# Main entry point

function Show-Usage {
    Write-Host @"
BundleDownload v$BUNDLEDOWNLOAD_VERSION - One-command developer tool installer

Usage:
  install.ps1 [options]

Options:
  -Preset <name>    Use a built-in preset (dannys-stack, frontend-dev, cloud-ops, full-stack)
  -Config <path>    Load tools from a JSON config file (local path or URL)
  -Yes              Skip interactive prompts, install immediately
  -List             List available presets and exit
  -Help             Show this help message

Examples:
  irm https://bundledownload.dev/install.ps1 | iex
  .\install.ps1 -Preset dannys-stack
  .\install.ps1 -Config .\team-tools.json -Yes
"@
}

# Parse args from $args (needed when piped via iex)
$Preset = ""
$Config = ""
$AutoYes = $false
$ListPresets = $false
$ShowHelp = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        { $_ -in "--preset", "-Preset" }  { $Preset = $args[++$i] }
        { $_ -in "--config", "-Config" }  { $Config = $args[++$i] }
        { $_ -in "--yes", "-Yes", "-y" }  { $AutoYes = $true }
        { $_ -in "--list", "-List" }      { $ListPresets = $true }
        { $_ -in "--help", "-Help", "-h" } { $ShowHelp = $true }
    }
}

# Detect OS
Detect-OS
Ensure-PackageManager
Print-SystemInfo

if ($ShowHelp) { Show-Usage; exit 0 }

if ($ListPresets) {
    Write-Host " Available presets:`n" -ForegroundColor White
    foreach ($name in $BUILTIN_PRESETS.Keys) {
        Write-Host "  $name" -ForegroundColor Cyan
        Write-Host "    $($BUILTIN_PRESETS[$name] -join ', ')`n"
    }
    exit 0
}

# Load tool selection
if ($Config) {
    if (-not (Load-ConfigFile $Config)) { exit 1 }
} elseif ($Preset) {
    if (-not (Load-Preset $Preset)) { exit 1 }
} elseif (Auto-DetectConfig) {
    # Config loaded
} elseif ($AutoYes) {
    Write-Err "No preset or config specified with -Yes. Use -Preset or -Config."
    exit 1
} else {
    Show-InteractivePicker
}

# Confirm if not auto
if (-not $AutoYes -and ($Preset -or $Config)) {
    Write-Host " Tools to install: $($script:SELECTED_TOOLS -join ', ')" -ForegroundColor Cyan
    Write-Host " Press Enter to continue, Ctrl+C to cancel..." -ForegroundColor DarkGray -NoNewline
    Read-Host
    Write-Host ""
}

# Run installation
Run-Install
```

- [ ] **Step 3: Build and do a dry-run test**

Run: `bash build.sh`
Then test help: `bash install.sh --help`
Expected: Usage text prints correctly.

Then test list: `bash install.sh --list`
Expected: All 4 presets printed with their tool lists.

- [ ] **Step 4: Commit**

```bash
git add src/sh/main.sh src/ps1/main.ps1
git commit -m "feat: main entry point with arg parsing, preset loading, and orchestration"
```

---

### Task 8: End-to-End Testing

**Files:** No new files. Testing the built scripts.

- [ ] **Step 1: Build final scripts**

Run: `bash build.sh`

- [ ] **Step 2: Test `--help` on both platforms**

Bash: `bash install.sh --help`
PowerShell: `powershell -File install.ps1 -Help`

Expected: Usage text with version, options, and examples.

- [ ] **Step 3: Test `--list`**

Bash: `bash install.sh --list`
Expected: 4 presets with tool lists.

- [ ] **Step 4: Test preset loading (dry run)**

Bash: `bash install.sh --preset dannys-stack --yes`
Expected: Detects OS, shows system info, installs/skips 8 tools, shows summary.

- [ ] **Step 5: Test already-installed detection**

Run the same command again.
Expected: All 8 tools show "already installed", 0 newly installed.

- [ ] **Step 6: Test interactive picker**

Bash: `bash install.sh` (no args)
Expected: Picker appears with dannys-stack pre-selected. Arrow keys, space, enter all work.

- [ ] **Step 7: Test config file**

Create a test config:
```bash
echo '{"name":"test","tools":["git","node"]}' > /tmp/test-config.json
bash install.sh --config /tmp/test-config.json --yes
```
Expected: Only git and node attempted.

- [ ] **Step 8: Test Windows (if available)**

PowerShell: `.\install.ps1 -Preset dannys-stack -Yes`
Expected: winget-based installs for standalone tools, npm installs for npm tools.

- [ ] **Step 9: Fix any issues found, rebuild, and commit**

```bash
bash build.sh
git add -A
git commit -m "fix: address issues found during end-to-end testing"
```

---

### Task 9: Final Polish + Initial Commit

**Files:**
- Modify: Various files for any fixes

- [ ] **Step 1: Review all source files for consistency**

Check that tool IDs, preset names, and phase assignments match between bash and PowerShell versions.

- [ ] **Step 2: Build final distributable scripts**

Run: `bash build.sh`
Verify both `install.sh` and `install.ps1` are complete and functional.

- [ ] **Step 3: Initialize git repo and make initial commit**

```bash
git init
git add .
git commit -m "feat: BundleDownload v1.0.0 — one-command developer tool installer

Cross-platform CLI tool that installs curated developer tools with
a single command. Supports macOS, Linux, and Windows.

- 12 supported tools: git, node, gh, gcloud, az, aws, vercel, supabase, wrangler, claude-code, whisperflow, tabby
- 4 built-in presets: dannys-stack, frontend-dev, cloud-ops, full-stack
- Interactive picker with keyboard navigation
- JSON config file support for custom presets
- Dependency-aware phased installation
- Already-installed detection
- curl|bash (Mac/Linux) and irm|iex (Windows) distribution"
```

- [ ] **Step 4: Verify final build**

```bash
bash build.sh
bash install.sh --help
bash install.sh --list
```

All commands should work. Done!
