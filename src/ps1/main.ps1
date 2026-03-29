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
