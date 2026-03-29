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
    MINGW*|MSYS*|CYGWIN*)
      BD_OS="windows"
      BD_DISTRO="windows"
      BD_PKG_MGR="winget"
      log_warn "Detected Windows via Git Bash. For best results, use install.ps1 in PowerShell."
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
