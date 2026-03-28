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
