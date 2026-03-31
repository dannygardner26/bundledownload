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
