#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$BUNDLEDOWNLOAD_VERSION = "1.0.0"

function Write-Info    { param([string]$Msg) Write-Host "[info] " -ForegroundColor Blue -NoNewline; Write-Host $Msg }
function Write-Success { param([string]$Msg) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Err     { param([string]$Msg) Write-Host "[FAIL] " -ForegroundColor Red -NoNewline; Write-Host $Msg }
function Write-Skip    { param([string]$Msg) Write-Host "[skip] " -ForegroundColor DarkGray -NoNewline; Write-Host $Msg }

function Test-CommandExists { param([string]$Cmd) return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue) }
# OS Detection for Windows
# Sets: $script:BD_OS, $script:BD_ARCH, $script:BD_WINVER, $script:BD_HAS_WINGET, $script:BD_HAS_SCOOP

function Detect-OS {
    $script:BD_OS = "windows"
    $script:BD_ARCH = if ([System.Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $script:BD_WINVER = [System.Environment]::OSVersion.Version.ToString()
    $script:BD_HAS_WINGET = Test-CommandExists "winget"
    $script:BD_HAS_SCOOP = Test-CommandExists "scoop"
}

function Ensure-PackageManager {
    if (-not $script:BD_HAS_WINGET) {
        Write-Err "winget is not available. Please install App Installer from the Microsoft Store."
        Write-Err "https://aka.ms/getwinget"
        exit 1
    }
}

function Print-SystemInfo {
    Write-Host ""
    Write-Host " BundleDownload v$BUNDLEDOWNLOAD_VERSION" -ForegroundColor White
    Write-Host " Detected: Windows $($script:BD_WINVER) ($($script:BD_ARCH))" -NoNewline -ForegroundColor DarkGray
    if ($script:BD_HAS_WINGET) { Write-Host " -winget available" -ForegroundColor DarkGray -NoNewline }
    if ($script:BD_HAS_SCOOP)  { Write-Host " -scoop available" -ForegroundColor DarkGray -NoNewline }
    Write-Host "`n"
}
# Tool Registry for Windows

$ALL_TOOL_IDS = @("git", "node", "python", "java", "bun", "rust", "cpp", "gh", "gcloud", "az", "aws", "vercel", "cloudflare", "supabase", "docker", "terraform", "kubectl", "claude-code", "whisperflow", "tabby")

$TOOL_PHASE = @{
    "git" = 1; "node" = 1; "python" = 1; "java" = 1; "bun" = 1; "rust" = 1; "cpp" = 1
    "vercel" = 2; "cloudflare" = 2; "supabase" = 2
    "gh" = 3; "aws" = 3; "az" = 3; "gcloud" = 3; "claude-code" = 3; "docker" = 3; "terraform" = 3; "kubectl" = 3
    "tabby" = 4; "whisperflow" = 4
}

$TOOL_DEPS = @{
    "vercel"     = @("node")
    "cloudflare" = @("node")
    "kubectl"    = @("docker")
}

$TOOL_NAME = @{
    "git" = "Git"; "node" = "Node.js (via fnm)"; "python" = "Python 3"; "java" = "Java (OpenJDK)"
    "bun" = "Bun"; "rust" = "Rust (rustup)"; "cpp" = "C/C++ Build Tools"
    "gh" = "GitHub CLI"; "gcloud" = "Google Cloud CLI"; "az" = "Azure CLI"; "aws" = "AWS CLI"
    "vercel" = "Vercel CLI"; "supabase" = "Supabase CLI"; "cloudflare" = "Cloudflare CLI"
    "claude-code" = "Claude Code"; "docker" = "Docker"; "terraform" = "Terraform"; "kubectl" = "kubectl"
    "whisperflow" = "WhisperFlow"; "tabby" = "Tabby Terminal"
}

$TOOL_VERSION_CMD = @{
    "git" = "git --version"; "node" = "node --version"; "python" = "python --version"
    "java" = "java --version"; "bun" = "bun --version"; "rust" = "rustc --version"
    "cpp" = "gcc --version"; "gh" = "gh --version"; "gcloud" = "gcloud --version"
    "az" = "az --version"; "aws" = "aws --version"; "vercel" = "vercel --version"
    "supabase" = "supabase --version"; "cloudflare" = "wrangler --version"
    "claude-code" = "claude --version"; "docker" = "docker --version"
    "terraform" = "terraform --version"; "kubectl" = "kubectl version --client"
    "whisperflow" = "whisperflow --version"; "tabby" = ""
}

function Test-ToolInstalled {
    param([string]$Id)
    $cmd = $TOOL_VERSION_CMD[$Id]
    if ([string]::IsNullOrEmpty($cmd)) {
        # Desktop apps
        switch ($Id) {
            "tabby" {
                $paths = @(
                    "$env:LOCALAPPDATA\Programs\Tabby\Tabby.exe",
                    "$env:ProgramFiles\Tabby\Tabby.exe"
                )
                foreach ($p in $paths) { if (Test-Path $p) { return "installed" } }
                return $null
            }
        }
        return $null
    }
    try {
        $result = Invoke-Expression "$cmd 2>`$null" 2>$null
        if ($result) { return ($result | Select-Object -First 1) }
    } catch {}
    return $null
}

function Install-Tool {
    param([string]$Id)
    switch ($Id) {
        "git"         { winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements }
        "node"        {
            winget install --id Schniz.fnm -e --accept-source-agreements --accept-package-agreements
            $env:PATH = "$env:LOCALAPPDATA\fnm;$env:PATH"
            fnm env --use-on-cd | Out-String | Invoke-Expression
            fnm install --lts
            fnm default lts-latest
        }
        "gh"          { winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements }
        "gcloud"      {
            $installer = "$env:TEMP\google-cloud-sdk-installer.exe"
            Invoke-WebRequest -Uri "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe" -OutFile $installer
            Start-Process -FilePath $installer -ArgumentList "/S" -Wait
            Remove-Item $installer -Force
        }
        "az"          { winget install --id Microsoft.AzureCLI -e --accept-source-agreements --accept-package-agreements }
        "aws"         {
            $msi = "$env:TEMP\AWSCLIV2.msi"
            Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $msi
            Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn" -Wait
            Remove-Item $msi -Force
        }
        "vercel"      { npm install -g vercel }
        "supabase"    {
            if ($script:BD_HAS_SCOOP) {
                scoop bucket add supabase https://github.com/supabase/scoop-bucket.git 2>$null
                scoop install supabase
            } else {
                npm install -g supabase
            }
        }
        "cloudflare"  { npm install -g wrangler }
        "claude-code" { Invoke-Expression "& { $(Invoke-RestMethod https://claude.ai/install.ps1) }" }
        "python"      { winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements }
        "java"        { winget install --id Microsoft.OpenJDK.21 -e --accept-source-agreements --accept-package-agreements }
        "bun"         { powershell -c "irm bun.sh/install.ps1 | iex" }
        "rust"        { winget install --id Rustlang.Rustup -e --accept-source-agreements --accept-package-agreements }
        "cpp"         { winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-source-agreements --accept-package-agreements --override "--passive --add Microsoft.VisualStudio.Workload.VCTools" }
        "docker"      { winget install --id Docker.DockerDesktop -e --accept-source-agreements --accept-package-agreements }
        "terraform"   { winget install --id Hashicorp.Terraform -e --accept-source-agreements --accept-package-agreements }
        "kubectl"     { winget install --id Kubernetes.kubectl -e --accept-source-agreements --accept-package-agreements }
        "whisperflow" { pip install whisperflow }
        "tabby"       { winget install --id Eugeny.Tabby -e --accept-source-agreements --accept-package-agreements }
        default       { Write-Err "Unknown tool: $Id"; return $false }
    }
    return $true
}
# Preset System

$BUILTIN_PRESETS = @{
    "dannys-stack" = @("node", "git", "gh", "claude-code", "vercel", "supabase", "cloudflare", "tabby")
    "ai-builder"   = @("node", "git", "gh", "claude-code", "gcloud", "vercel", "supabase", "cloudflare", "whisperflow")
    "frontend-dev" = @("node", "git", "gh", "vercel", "cloudflare")
    "cloud-ops"    = @("git", "gh", "aws", "az", "gcloud", "terraform", "kubectl", "docker")
    "full-stack"   = @("git", "node", "python", "java", "bun", "rust", "cpp", "gh", "gcloud", "az", "aws", "vercel", "cloudflare", "supabase", "docker", "terraform", "kubectl", "claude-code", "whisperflow", "tabby")
}

$script:SELECTED_TOOLS = @()

function Load-Preset {
    param([string]$Name)
    if ($BUILTIN_PRESETS.ContainsKey($Name)) {
        $script:SELECTED_TOOLS = $BUILTIN_PRESETS[$Name]
        Write-Info "Loaded preset: $Name ($($script:SELECTED_TOOLS.Count) tools)"
        return $true
    }
    Write-Err "Unknown preset: $Name"
    Write-Info "Available presets: $($BUILTIN_PRESETS.Keys -join ', ')"
    return $false
}

function Load-ConfigFile {
    param([string]$Path)
    try {
        $json = if ($Path -match '^https?://') {
            (Invoke-RestMethod -Uri $Path)
        } elseif (Test-Path $Path) {
            Get-Content $Path -Raw | ConvertFrom-Json
        } else {
            Write-Err "Config file not found: $Path"
            return $false
        }
        $script:SELECTED_TOOLS = @($json.tools)
        $name = if ($json.name) { $json.name } else { "custom" }
        Write-Info "Loaded config: $name ($($script:SELECTED_TOOLS.Count) tools)"
        return $true
    } catch {
        Write-Err "Failed to parse config: $_"
        return $false
    }
}

function Auto-DetectConfig {
    if (Test-Path "bundledownload.json") {
        Write-Info "Found bundledownload.json in current directory"
        return Load-ConfigFile "bundledownload.json"
    }
    return $false
}
# Interactive UI for Windows

function Show-InteractivePicker {
    $cursor = 0
    $toolIds = $ALL_TOOL_IDS
    $count = $toolIds.Count

    # Pre-select dannys-stack
    $preselected = @{}
    foreach ($t in $BUILTIN_PRESETS["dannys-stack"]) { $preselected[$t] = $true }

    $isSelected = @()
    foreach ($id in $toolIds) {
        $isSelected += if ($preselected.ContainsKey($id)) { $true } else { $false }
    }

    [Console]::CursorVisible = $false

    Write-Host " Select tools to install" -ForegroundColor White
    Write-Host " Up/Down = move  Space = toggle  a = all  n = none  Enter = install" -ForegroundColor DarkGray
    Write-Host ""

    $listTop = [Console]::CursorTop

    function Draw-List {
        [Console]::SetCursorPosition(0, $listTop)
        for ($i = 0; $i -lt $count; $i++) {
            $id = $toolIds[$i]
            $name = $TOOL_NAME[$id]
            $marker = if ($isSelected[$i]) { "x" } else { " " }
            $prefix = if ($i -eq $cursor) { ">" } else { " " }
            $color = if ($isSelected[$i]) { "Cyan" } else { "Gray" }

            Write-Host ("  {0} [{1}] {2}" -f $prefix, $marker, $name).PadRight(60) -ForegroundColor $color
        }
    }

    Draw-List

    while ($true) {
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { if ($cursor -gt 0) { $cursor-- } }
            "DownArrow" { if ($cursor -lt ($count - 1)) { $cursor++ } }
            "Spacebar"  { $isSelected[$cursor] = -not $isSelected[$cursor] }
            "A"         { for ($i = 0; $i -lt $count; $i++) { $isSelected[$i] = $true } }
            "N"         { for ($i = 0; $i -lt $count; $i++) { $isSelected[$i] = $false } }
            "Enter"     { break }
        }
        Draw-List
    }

    [Console]::CursorVisible = $true

    $script:SELECTED_TOOLS = @()
    for ($i = 0; $i -lt $count; $i++) {
        if ($isSelected[$i]) { $script:SELECTED_TOOLS += $toolIds[$i] }
    }

    if ($script:SELECTED_TOOLS.Count -eq 0) {
        Write-Warn "No tools selected. Exiting."
        exit 0
    }

    Write-Host "`n $($script:SELECTED_TOOLS.Count) tools selected`n" -ForegroundColor White
}

function Write-ProgressStart {
    param([string]$Id)
    $name = $TOOL_NAME[$Id]
    Write-Host " [..] $name - installing..." -ForegroundColor Yellow
}

function Write-ProgressDone {
    param([string]$Id, [string]$Version = "installed")
    $name = $TOOL_NAME[$Id]
    [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
    $line = " [ok] $name - $Version"
    Write-Host $line.PadRight(60) -ForegroundColor Green
}

function Write-ProgressSkip {
    param([string]$Id, [string]$Version)
    $name = $TOOL_NAME[$Id]
    Write-Host " [ok] $name $Version - already installed" -ForegroundColor Green
}

function Write-ProgressFail {
    param([string]$Id, [string]$Err = "failed")
    $name = $TOOL_NAME[$Id]
    [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
    $line = " [!!] $name - $Err"
    Write-Host $line.PadRight(60) -ForegroundColor Red
}
# Installer Engine for Windows

function Run-Install {
    $tools = $script:SELECTED_TOOLS
    $total = $tools.Count
    $installed = 0
    $skipped = 0
    $failed = 0
    $failedTools = @()
    $installedTools = @()
    $skippedTools = @()
    $nextSteps = @()

    # Group by phase
    $phases = @{ 1 = @(); 2 = @(); 3 = @(); 4 = @() }
    foreach ($id in $tools) {
        $phase = $TOOL_PHASE[$id]
        $phases[$phase] += $id
    }

    Write-Host " Installing $total tools...`n" -ForegroundColor White

    foreach ($phaseNum in (1..4)) {
        foreach ($id in $phases[$phaseNum]) {
            $version = Test-ToolInstalled $id
            if ($version) {
                Write-ProgressSkip $id $version
                $skipped++
                $skippedTools += $id
                continue
            }

            Write-ProgressStart $id
            try {
                $result = Install-Tool $id
                $version = Test-ToolInstalled $id
                if (-not $version) { $version = "installed" }
                Write-ProgressDone $id $version
                $installed++
                $installedTools += $id

                switch ($id) {
                    "gh"          { $nextSteps += "Run ``gh auth login`` to authenticate with GitHub" }
                    "claude-code" { $nextSteps += "Run ``claude`` to set up Claude Code" }
                    "vercel"      { $nextSteps += "Run ``vercel login`` to connect your Vercel account" }
                    "gcloud"      { $nextSteps += "Run ``gcloud init`` to configure Google Cloud" }
                    "az"          { $nextSteps += "Run ``az login`` to authenticate with Azure" }
                    "aws"         { $nextSteps += "Run ``aws configure`` to set up AWS credentials" }
                    "supabase"    { $nextSteps += "Run ``supabase login`` to authenticate with Supabase" }
                    "wrangler"    { $nextSteps += "Run ``wrangler login`` to authenticate with Cloudflare" }
                }
            } catch {
                Write-ProgressFail $id $_.Exception.Message
                $failed++
                $failedTools += $id
            }
        }
    }

    # Summary
    Write-Host ""
    $summary = " Done! $installed installed, $skipped already present"
    if ($failed -gt 0) { $summary += ", $failed failed" }
    Write-Host $summary -ForegroundColor White
    Write-Host ""

    if ($installedTools.Count -gt 0) { Write-Host " Installed: $($installedTools -join ', ')" -ForegroundColor Green }
    if ($skippedTools.Count -gt 0)   { Write-Host " Skipped:   $($skippedTools -join ', ')" -ForegroundColor DarkGray }
    if ($failedTools.Count -gt 0)    { Write-Host " Failed:    $($failedTools -join ', ')" -ForegroundColor Red }

    if ($nextSteps.Count -gt 0) {
        Write-Host "`n Next steps:" -ForegroundColor White
        foreach ($step in $nextSteps) {
            Write-Host "   * $step"
        }
    }
    Write-Host ""

    if ($failed -gt 0) { exit 1 }
}
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
