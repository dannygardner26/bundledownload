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
