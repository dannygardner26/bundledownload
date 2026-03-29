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
