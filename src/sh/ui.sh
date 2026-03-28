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
