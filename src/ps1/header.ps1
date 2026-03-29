#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$BUNDLEDOWNLOAD_VERSION = "1.0.0"

function Write-Info    { param([string]$Msg) Write-Host "[info] " -ForegroundColor Blue -NoNewline; Write-Host $Msg }
function Write-Success { param([string]$Msg) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Err     { param([string]$Msg) Write-Host "[FAIL] " -ForegroundColor Red -NoNewline; Write-Host $Msg }
function Write-Skip    { param([string]$Msg) Write-Host "[skip] " -ForegroundColor DarkGray -NoNewline; Write-Host $Msg }

function Test-CommandExists { param([string]$Cmd) return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue) }
