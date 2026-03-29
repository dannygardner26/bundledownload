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
