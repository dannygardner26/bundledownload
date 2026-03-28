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
    Write-Host " [..] $($TOOL_NAME[$Id]) — installing..." -ForegroundColor Yellow
}

function Write-ProgressDone {
    param([string]$Id, [string]$Version = "installed")
    # Overwrite previous line
    [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
    Write-Host (" [ok] {0} — {1}" -f $TOOL_NAME[$Id], $Version).PadRight(60) -ForegroundColor Green
}

function Write-ProgressSkip {
    param([string]$Id, [string]$Version)
    Write-Host " [ok] $($TOOL_NAME[$Id]) $Version — already installed" -ForegroundColor Green
}

function Write-ProgressFail {
    param([string]$Id, [string]$Err = "failed")
    [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
    Write-Host (" [!!] {0} — {1}" -f $TOOL_NAME[$Id], $Err).PadRight(60) -ForegroundColor Red
}
