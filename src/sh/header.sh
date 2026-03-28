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
