# Tool Registry
# Each tool is defined by a set of variables: TOOL_<ID>_*

# All tool IDs in display order
ALL_TOOL_IDS=(git node python java bun rust cpp gh gcloud az aws vercel cloudflare supabase docker terraform kubectl claude-code whisperflow tabby)

# Phase assignments (1=foundations, 2=npm-tools, 3=standalone, 4=apps)
declare -A TOOL_PHASE=(
  [git]=1 [node]=1 [python]=1 [java]=1 [bun]=1 [rust]=1 [cpp]=1
  [vercel]=2 [cloudflare]=2 [supabase]=2
  [gh]=3 [aws]=3 [az]=3 [gcloud]=3 [claude-code]=3 [docker]=3 [terraform]=3 [kubectl]=3
  [tabby]=4 [whisperflow]=4
)

# Dependencies (tool ID -> space-separated dependency IDs)
declare -A TOOL_DEPS=(
  [vercel]="node"
  [cloudflare]="node"
  [kubectl]="docker"
)

# Display names
declare -A TOOL_NAME=(
  [git]="Git"
  [node]="Node.js (via fnm)"
  [python]="Python 3"
  [java]="Java (OpenJDK)"
  [bun]="Bun"
  [rust]="Rust (rustup)"
  [cpp]="C/C++ Build Tools"
  [gh]="GitHub CLI"
  [gcloud]="Google Cloud CLI"
  [az]="Azure CLI"
  [aws]="AWS CLI"
  [vercel]="Vercel CLI"
  [supabase]="Supabase CLI"
  [cloudflare]="Cloudflare CLI"
  [claude-code]="Claude Code"
  [docker]="Docker"
  [terraform]="Terraform"
  [kubectl]="kubectl"
  [whisperflow]="WhisperFlow"
  [tabby]="Tabby Terminal"
)

# Version check commands
declare -A TOOL_VERSION_CMD=(
  [git]="git --version"
  [node]="node --version"
  [python]="python3 --version"
  [java]="java --version 2>&1 | head -1"
  [bun]="bun --version"
  [rust]="rustc --version"
  [cpp]="gcc --version 2>&1 | head -1 || clang --version 2>&1 | head -1"
  [gh]="gh --version"
  [gcloud]="gcloud --version 2>/dev/null | head -1"
  [az]="az --version 2>/dev/null | head -1"
  [aws]="aws --version"
  [vercel]="vercel --version 2>/dev/null"
  [supabase]="supabase --version"
  [cloudflare]="wrangler --version 2>/dev/null"
  [claude-code]="claude --version 2>/dev/null"
  [docker]="docker --version"
  [terraform]="terraform --version 2>/dev/null | head -1"
  [kubectl]="kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1"
  [whisperflow]="whisperflow --version 2>/dev/null"
  [tabby]=""
)

# Check if tool is already installed. Returns 0 if installed, 1 if not.
# Prints version string if installed.
tool_check_installed() {
  local id="$1"
  local cmd="${TOOL_VERSION_CMD[$id]}"
  if [[ -z "$cmd" ]]; then
    # Desktop apps — check common locations
    case "$id" in
      tabby)
        case "$BD_OS" in
          macos)  [[ -d "/Applications/Tabby.app" ]] && echo "installed" && return 0 ;;
          linux)  command_exists tabby && echo "installed" && return 0 ;;
        esac
        ;;
    esac
    return 1
  fi
  local version
  version=$(eval "$cmd" 2>/dev/null) && echo "$version" && return 0
  return 1
}

# Install a single tool. Expects BD_OS, BD_DISTRO, BD_PKG_MGR to be set.
tool_install() {
  local id="$1"
  case "$id" in
    git)
      case "$BD_PKG_MGR" in
        brew)   brew install git ;;
        apt)    sudo apt-get install -y git ;;
        dnf)    sudo dnf install -y git ;;
        pacman) sudo pacman -S --noconfirm git ;;
      esac
      ;;
    node)
      case "$BD_OS" in
        macos)
          brew install fnm
          ;;
        linux)
          curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
          export PATH="$HOME/.local/share/fnm:$PATH"
          ;;
      esac
      eval "$(fnm env)"
      fnm install --lts
      fnm default lts-latest
      ;;
    gh)
      case "$BD_PKG_MGR" in
        brew)   brew install gh ;;
        apt)
          sudo mkdir -p -m 755 /etc/apt/keyrings
          curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
          echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
          sudo apt-get update -qq && sudo apt-get install -y gh
          ;;
        dnf)    sudo dnf install -y gh ;;
        pacman) sudo pacman -S --noconfirm github-cli ;;
      esac
      ;;
    gcloud)
      case "$BD_PKG_MGR" in
        brew) brew install google-cloud-sdk ;;
        apt)
          curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
          echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null
          sudo apt-get update -qq && sudo apt-get install -y google-cloud-cli
          ;;
        dnf) sudo dnf install -y google-cloud-cli ;;
        *)   curl https://sdk.cloud.google.com | bash -s -- --disable-prompts ;;
      esac
      ;;
    az)
      case "$BD_PKG_MGR" in
        brew) brew install azure-cli ;;
        apt)  curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash ;;
        dnf)  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc && sudo dnf install -y azure-cli ;;
        *)    curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash ;;
      esac
      ;;
    aws)
      case "$BD_OS" in
        macos)
          curl -fsSL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o /tmp/AWSCLIV2.pkg
          sudo installer -pkg /tmp/AWSCLIV2.pkg -target /
          rm -f /tmp/AWSCLIV2.pkg
          ;;
        linux)
          curl -fsSL "https://awscli.amazonaws.com/awscliv2-linux-$(uname -m).zip" -o /tmp/awscliv2.zip
          unzip -qo /tmp/awscliv2.zip -d /tmp/aws-install
          sudo /tmp/aws-install/aws/install --update
          rm -rf /tmp/awscliv2.zip /tmp/aws-install
          ;;
      esac
      ;;
    vercel)
      npm install -g vercel
      ;;
    supabase)
      case "$BD_PKG_MGR" in
        brew) brew install supabase/tap/supabase ;;
        *)
          local latest
          latest=$(curl -fsSL https://api.github.com/repos/supabase/cli/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
          curl -fsSL "https://github.com/supabase/cli/releases/download/v${latest}/supabase_linux_$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/').tar.gz" | sudo tar -xz -C /usr/local/bin supabase
          ;;
      esac
      ;;
    cloudflare)
      npm install -g wrangler
      ;;
    claude-code)
      curl -fsSL https://claude.ai/install.sh | bash
      ;;
    whisperflow)
      case "$BD_PKG_MGR" in
        brew)   brew install portaudio && pip3 install whisperflow ;;
        apt)    sudo apt-get install -y portaudio19-dev && pip3 install whisperflow ;;
        dnf)    sudo dnf install -y portaudio-devel && pip3 install whisperflow ;;
        pacman) sudo pacman -S --noconfirm portaudio && pip3 install whisperflow ;;
      esac
      ;;
    tabby)
      case "$BD_PKG_MGR" in
        brew) brew install --cask tabby ;;
        *)
          local latest
          latest=$(curl -fsSL https://api.github.com/repos/Eugeny/tabby/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
          local arch_suffix
          arch_suffix=$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/')
          curl -fsSL "https://github.com/Eugeny/tabby/releases/download/v${latest}/tabby-${latest}-linux-${arch_suffix}.deb" -o /tmp/tabby.deb
          sudo dpkg -i /tmp/tabby.deb || sudo apt-get install -f -y
          rm -f /tmp/tabby.deb
          ;;
      esac
      ;;
    python)
      case "$BD_PKG_MGR" in
        brew)   brew install python@3 ;;
        apt)    sudo apt-get install -y python3 python3-pip python3-venv ;;
        dnf)    sudo dnf install -y python3 python3-pip ;;
        pacman) sudo pacman -S --noconfirm python python-pip ;;
      esac
      ;;
    java)
      case "$BD_PKG_MGR" in
        brew)   brew install openjdk ;;
        apt)    sudo apt-get install -y default-jdk ;;
        dnf)    sudo dnf install -y java-latest-openjdk-devel ;;
        pacman) sudo pacman -S --noconfirm jdk-openjdk ;;
      esac
      ;;
    bun)
      curl -fsSL https://bun.sh/install | bash
      export PATH="$HOME/.bun/bin:$PATH"
      ;;
    rust)
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
      source "$HOME/.cargo/env" 2>/dev/null || export PATH="$HOME/.cargo/bin:$PATH"
      ;;
    cpp)
      case "$BD_OS" in
        macos)
          xcode-select --install 2>/dev/null || log_info "Xcode CLI tools already installed"
          ;;
        linux)
          case "$BD_PKG_MGR" in
            apt)    sudo apt-get install -y build-essential ;;
            dnf)    sudo dnf groupinstall -y "Development Tools" ;;
            pacman) sudo pacman -S --noconfirm base-devel ;;
          esac
          ;;
      esac
      ;;
    docker)
      case "$BD_OS" in
        macos)
          brew install --cask docker
          ;;
        linux)
          case "$BD_PKG_MGR" in
            apt)    curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker "$USER" ;;
            dnf)    sudo dnf install -y dnf-plugins-core && sudo dnf install -y docker-ce docker-ce-cli containerd.io && sudo systemctl enable --now docker && sudo usermod -aG docker "$USER" ;;
            pacman) sudo pacman -S --noconfirm docker && sudo systemctl enable --now docker && sudo usermod -aG docker "$USER" ;;
          esac
          ;;
      esac
      ;;
    terraform)
      case "$BD_PKG_MGR" in
        brew) brew install terraform ;;
        apt)
          curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
          echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
          sudo apt-get update -qq && sudo apt-get install -y terraform
          ;;
        dnf)  sudo dnf install -y terraform ;;
        pacman) sudo pacman -S --noconfirm terraform ;;
      esac
      ;;
    kubectl)
      case "$BD_PKG_MGR" in
        brew) brew install kubectl ;;
        apt)
          curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')/kubectl" -o /tmp/kubectl
          sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
          rm -f /tmp/kubectl
          ;;
        dnf) sudo dnf install -y kubectl ;;
        pacman) sudo pacman -S --noconfirm kubectl ;;
      esac
      ;;
    *)
      log_error "Unknown tool: $id"
      return 1
      ;;
  esac
}
