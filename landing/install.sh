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
# OS Detection
# Sets: BD_OS, BD_ARCH, BD_DISTRO, BD_PKG_MGR, BD_CPU_CORES, BD_MEM_GB, BD_SHELL

detect_os() {
  local uname_s
  uname_s="$(uname -s)"
  BD_ARCH="$(uname -m)"

  case "$uname_s" in
    Darwin)
      BD_OS="macos"
      BD_DISTRO="macos"
      BD_PKG_MGR="brew"
      BD_CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo "?")
      BD_MEM_GB=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))
      ;;
    Linux)
      BD_OS="linux"
      BD_CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "?")
      BD_MEM_GB=$(( $(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0) / 1048576 ))
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
          ubuntu|debian|pop|mint|elementary|linuxmint|neon) BD_DISTRO="debian"; BD_PKG_MGR="apt" ;;
          fedora|rhel|centos|rocky|alma|ol|amzn)            BD_DISTRO="fedora"; BD_PKG_MGR="dnf" ;;
          arch|manjaro|endeavouros|garuda|artix)             BD_DISTRO="arch";   BD_PKG_MGR="pacman" ;;
          opensuse*|sles)                                    BD_DISTRO="suse";   BD_PKG_MGR="zypper" ;;
          alpine)                                            BD_DISTRO="alpine"; BD_PKG_MGR="apk" ;;
          *)                                                 BD_DISTRO="unknown"; BD_PKG_MGR="unknown" ;;
        esac
      else
        BD_DISTRO="unknown"
        BD_PKG_MGR="unknown"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      BD_OS="windows"
      BD_DISTRO="windows"
      BD_PKG_MGR="winget"
      BD_CPU_CORES=$(nproc 2>/dev/null || echo "?")
      BD_MEM_GB="?"
      log_warn "Detected Windows via Git Bash. For best results, use install.ps1 in PowerShell."
      ;;
    *)
      log_error "Unsupported OS: $uname_s"
      exit 1
      ;;
  esac

  BD_SHELL="$(basename "${SHELL:-unknown}")"
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
  printf "${RESET}\n"
  printf " ${DIM}System:   %s cores, %sGB RAM, shell: %s${RESET}\n\n" "$BD_CPU_CORES" "$BD_MEM_GB" "$BD_SHELL"
}
# Tool Registry
# Each tool is defined by a set of variables: TOOL_<ID>_*

# All tool IDs in display order
ALL_TOOL_IDS=(git node python java bun rust cpp gh gcloud az aws vercel cloudflare supabase docker terraform kubectl claude-code whisperflow tabby)

# Phase assignments (1=foundations, 2=npm-tools, 3=standalone, 4=apps)
declare -A TOOL_PHASE=(
  [git]=1 [node]=1 [python]=1 [java]=1 [bun]=1 [rust]=1 [cpp]=1
  [vercel]=2 [cloudflare]=2 [supabase]=2
  [gh]=3 [aws]=3 [az]=3 [gcloud]=3 [claude-code]=3 [docker]=3 [terraform]=3 [kubectl]=3
  [tabby]=4 [whisperflow]=4
)

# Dependencies (tool ID -> space-separated dependency IDs)
declare -A TOOL_DEPS=(
  [vercel]="node"
  [cloudflare]="node"
  [kubectl]="docker"
)

# Display names
declare -A TOOL_NAME=(
  [git]="Git"
  [node]="Node.js (via fnm)"
  [python]="Python 3"
  [java]="Java (OpenJDK)"
  [bun]="Bun"
  [rust]="Rust (rustup)"
  [cpp]="C/C++ Build Tools"
  [gh]="GitHub CLI"
  [gcloud]="Google Cloud CLI"
  [az]="Azure CLI"
  [aws]="AWS CLI"
  [vercel]="Vercel CLI"
  [supabase]="Supabase CLI"
  [cloudflare]="Cloudflare CLI"
  [claude-code]="Claude Code"
  [docker]="Docker"
  [terraform]="Terraform"
  [kubectl]="kubectl"
  [whisperflow]="WhisperFlow"
  [tabby]="Tabby Terminal"
)

# Version check commands
declare -A TOOL_VERSION_CMD=(
  [git]="git --version"
  [node]="node --version"
  [python]="python3 --version"
  [java]="java --version 2>&1 | head -1"
  [bun]="bun --version"
  [rust]="rustc --version"
  [cpp]="gcc --version 2>&1 | head -1 || clang --version 2>&1 | head -1"
  [gh]="gh --version"
  [gcloud]="gcloud --version 2>/dev/null | head -1"
  [az]="az --version 2>/dev/null | head -1"
  [aws]="aws --version"
  [vercel]="vercel --version 2>/dev/null"
  [supabase]="supabase --version"
  [cloudflare]="wrangler --version 2>/dev/null"
  [claude-code]="claude --version 2>/dev/null"
  [docker]="docker --version"
  [terraform]="terraform --version 2>/dev/null | head -1"
  [kubectl]="kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1"
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
    cloudflare)
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
    python)
      case "$BD_PKG_MGR" in
        brew)   brew install python@3 ;;
        apt)    sudo apt-get install -y python3 python3-pip python3-venv ;;
        dnf)    sudo dnf install -y python3 python3-pip ;;
        pacman) sudo pacman -S --noconfirm python python-pip ;;
      esac
      ;;
    java)
      case "$BD_PKG_MGR" in
        brew)   brew install openjdk ;;
        apt)    sudo apt-get install -y default-jdk ;;
        dnf)    sudo dnf install -y java-latest-openjdk-devel ;;
        pacman) sudo pacman -S --noconfirm jdk-openjdk ;;
      esac
      ;;
    bun)
      curl -fsSL https://bun.sh/install | bash
      export PATH="$HOME/.bun/bin:$PATH"
      ;;
    rust)
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      source "$HOME/.cargo/env" 2>/dev/null || export PATH="$HOME/.cargo/bin:$PATH"
      ;;
    cpp)
      case "$BD_OS" in
        macos)
          xcode-select --install 2>/dev/null || log_info "Xcode CLI tools already installed"
          ;;
        linux)
          case "$BD_PKG_MGR" in
            apt)    sudo apt-get install -y build-essential ;;
            dnf)    sudo dnf groupinstall -y "Development Tools" ;;
            pacman) sudo pacman -S --noconfirm base-devel ;;
          esac
          ;;
      esac
      ;;
    docker)
      case "$BD_OS" in
        macos)
          brew install --cask docker
          ;;
        linux)
          case "$BD_PKG_MGR" in
            apt)    curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker "$USER" ;;
            dnf)    sudo dnf install -y dnf-plugins-core && sudo dnf install -y docker-ce docker-ce-cli containerd.io && sudo systemctl enable --now docker && sudo usermod -aG docker "$USER" ;;
            pacman) sudo pacman -S --noconfirm docker && sudo systemctl enable --now docker && sudo usermod -aG docker "$USER" ;;
          esac
          ;;
      esac
      ;;
    terraform)
      case "$BD_PKG_MGR" in
        brew) brew install terraform ;;
        apt)
          curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
          echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
          sudo apt-get update -qq && sudo apt-get install -y terraform
          ;;
        dnf)  sudo dnf install -y terraform ;;
        pacman) sudo pacman -S --noconfirm terraform ;;
      esac
      ;;
    kubectl)
      case "$BD_PKG_MGR" in
        brew) brew install kubectl ;;
        apt)
          curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')/kubectl" -o /tmp/kubectl
          sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
          rm -f /tmp/kubectl
          ;;
        dnf) sudo dnf install -y kubectl ;;
        pacman) sudo pacman -S --noconfirm kubectl ;;
      esac
      ;;
    *)
      log_error "Unknown tool: $id"
      return 1
      ;;
  esac
}
# Preset System

# Built-in presets (embedded so curl|bash works without extra downloads)
declare -A BUILTIN_PRESETS=(
  [dannys-stack]="node git gh claude-code vercel supabase cloudflare tabby"
  [ai-builder]="node git gh claude-code gcloud vercel supabase cloudflare whisperflow"
  [frontend-dev]="node git gh vercel cloudflare"
  [cloud-ops]="git gh aws az gcloud terraform kubectl docker"
  [full-stack]="git node python java bun rust cpp gh gcloud az aws vercel cloudflare supabase docker terraform kubectl claude-code whisperflow tabby"
)

BUILTIN_PRESET_NAMES=("dannys-stack" "ai-builder" "frontend-dev" "cloud-ops" "full-stack")

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

  # Parse JSON — try jq first, then python3, then basic grep fallback
  local tools_str
  if command_exists jq; then
    tools_str=$(echo "$json" | jq -r '.tools[]' 2>/dev/null | tr '\n' ' ')
  elif python3 -c "import json" 2>/dev/null; then
    tools_str=$(echo "$json" | python3 -c "import sys,json; print(' '.join(json.load(sys.stdin)['tools']))" 2>/dev/null)
  else
    # Fallback: basic grep/sed parser for simple JSON arrays
    tools_str=$(echo "$json" | grep -o '"tools"\s*:\s*\[.*\]' | grep -oP '"\K[a-z][-a-z0-9]*(?=")' | tr '\n' ' ')
  fi

  IFS=' ' read -ra SELECTED_TOOLS <<< "$tools_str"
  local config_name
  if command_exists jq; then
    config_name=$(echo "$json" | jq -r '.name // "custom"')
  else
    config_name=$(echo "$json" | grep -oP '"name"\s*:\s*"\K[^"]+' 2>/dev/null || echo "custom")
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
