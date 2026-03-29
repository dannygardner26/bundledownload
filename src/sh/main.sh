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
