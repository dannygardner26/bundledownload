# Preset System

$BUILTIN_PRESETS = @{
    "dannys-stack" = @("node", "git", "gh", "claude-code", "vercel", "supabase", "wrangler", "tabby")
    "frontend-dev" = @("node", "git", "gh", "vercel", "wrangler")
    "cloud-ops"    = @("git", "gh", "aws", "az", "gcloud")
    "full-stack"   = @("git", "node", "gh", "gcloud", "az", "aws", "vercel", "supabase", "wrangler", "claude-code", "whisperflow", "tabby")
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
