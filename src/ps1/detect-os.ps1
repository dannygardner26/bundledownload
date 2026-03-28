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
    if ($script:BD_HAS_WINGET) { Write-Host " — winget available" -ForegroundColor DarkGray -NoNewline }
    if ($script:BD_HAS_SCOOP)  { Write-Host " — scoop available" -ForegroundColor DarkGray -NoNewline }
    Write-Host "`n"
}
