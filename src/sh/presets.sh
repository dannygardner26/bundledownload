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
