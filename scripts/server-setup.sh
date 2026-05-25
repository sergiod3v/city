#!/usr/bin/env bash
# Unified Hetzner VPS setup — Ubuntu 24.04
# Runs as alejo. System tasks via sudo, dev tools scoped to user where possible.
# Idempotent. Safe to re-run.
#
# Usage:
#   git clone https://github.com/sergiod3v/city.git ~/workspace/city
#   bash ~/workspace/city/scripts/server-setup.sh

set -euo pipefail

log()  { echo -e "\n\033[1;34m[+] $*\033[0m"; }
skip() { echo -e "\033[1;33m[=] $*\033[0m"; }
warn() { echo -e "\033[1;31m[!] $*\033[0m"; }

if [[ $EUID -eq 0 ]]; then
  warn "Run as alejo, NOT root."; exit 1
fi

USER_NAME="$USER"
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN" "$HOME/.config/helix" "$HOME/workspace" "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
export PATH="$LOCAL_BIN:$PATH"

# ═══════════════════════════════════════════════════════
# STAGE 1: SYSTEM (sudo, unavoidable)
# ═══════════════════════════════════════════════════════

log "Sudo NOPASSWD"
if sudo -n true 2>/dev/null; then
  skip "passwordless sudo active"
else
  echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-$USER_NAME >/dev/null
  sudo chmod 0440 /etc/sudoers.d/90-$USER_NAME
fi

log "APT base packages"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y \
  ufw fail2ban htop curl git vim ca-certificates gnupg \
  lsb-release unattended-upgrades apt-listchanges \
  zsh tmux ripgrep fd-find bat fzf \
  build-essential pkg-config unzip jq wget \
  python3-pip python3-venv python3-full

log "Timezone + locale"
sudo timedatectl set-timezone America/Bogota || true
sudo locale-gen en_US.UTF-8 || true

log "SSH hardening"
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

log "UFW"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

log "fail2ban"
sudo tee /etc/fail2ban/jail.local >/dev/null <<'EOF'
[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 3600
findtime = 600
EOF
sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban

log "Auto security updates"
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

log "Sysctl tuning"
sudo tee /etc/sysctl.d/99-tuning.conf >/dev/null <<'EOF'
vm.swappiness=10
vm.overcommit_memory=1
net.ipv4.tcp_fin_timeout=15
net.core.somaxconn=1024
EOF
sudo sysctl --system >/dev/null

log "Swap 2GB"
if [[ -f /swapfile ]]; then
  skip "swapfile exists"
else
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

log "Docker (system service, alejo in docker group)"
if command -v docker &>/dev/null; then
  skip "docker installed"
else
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  ARCH=$(dpkg --print-architecture)
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo usermod -aG docker "$USER_NAME"
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
sudo systemctl enable --now docker
sudo systemctl restart docker

# Symlinks for Debian-renamed bins (user-local)
[[ -e "$LOCAL_BIN/fd"  ]] || ln -sf "$(which fdfind)" "$LOCAL_BIN/fd"
[[ -e "$LOCAL_BIN/bat" ]] || ln -sf "$(which batcat)" "$LOCAL_BIN/bat"

# ═══════════════════════════════════════════════════════
# STAGE 2: DEV TOOLS — scoped to alejo
# ═══════════════════════════════════════════════════════

# ─── nvm + node (user-local, no sudo npm) ──
log "nvm + node (user-local)"
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
. "$NVM_DIR/nvm.sh"
if ! nvm ls 22 &>/dev/null; then
  nvm install 22
  nvm alias default 22
fi
nvm use default

# ─── Claude Code (user npm global, no sudo) ──
log "Claude Code (user npm)"
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code
else
  skip "claude code"
fi

# ─── starship (user-local) ──
log "starship → ~/.local/bin"
if ! command -v starship &>/dev/null; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN"
fi

# ─── zoxide (user-local default) ──
log "zoxide → ~/.local/bin"
command -v zoxide &>/dev/null || curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

# ─── lazygit (user-local) ──
log "lazygit → ~/.local/bin"
if ! command -v lazygit &>/dev/null; then
  LG_VER=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_VER}_Linux_x86_64.tar.gz"
  tar xf /tmp/lazygit.tar.gz -C "$LOCAL_BIN" lazygit
  rm /tmp/lazygit.tar.gz
fi

# ─── delta (user-local binary, no .deb sudo install) ──
log "git-delta → ~/.local/bin"
if ! command -v delta &>/dev/null; then
  DV=$(curl -s "https://api.github.com/repos/dandavison/delta/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
  curl -Lo /tmp/delta.tar.gz "https://github.com/dandavison/delta/releases/latest/download/delta-${DV}-x86_64-unknown-linux-gnu.tar.gz"
  tar xf /tmp/delta.tar.gz -C /tmp
  cp "/tmp/delta-${DV}-x86_64-unknown-linux-gnu/delta" "$LOCAL_BIN/"
  rm -rf /tmp/delta.tar.gz "/tmp/delta-${DV}-x86_64-unknown-linux-gnu"
fi

# ─── eza (system — apt only path, no clean user binary) ──
log "eza"
if ! command -v eza &>/dev/null; then
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  sudo apt-get update -y
  sudo apt-get install -y eza
fi

# ─── btop (system) ──
sudo apt-get install -y btop 2>/dev/null || skip "btop unavailable"

# ─── gh CLI (system — official apt repo) ──
log "gh CLI"
if ! command -v gh &>/dev/null; then
  sudo mkdir -p -m 755 /etc/apt/keyrings
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y gh
fi

# ─── Helix (user-local binary from GitHub) ──
log "helix → ~/.local/bin"
if ! command -v hx &>/dev/null; then
  HX_VER=$(curl -s "https://api.github.com/repos/helix-editor/helix/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
  curl -Lo /tmp/helix.tar.xz "https://github.com/helix-editor/helix/releases/download/${HX_VER}/helix-${HX_VER}-x86_64-linux.tar.xz"
  tar xf /tmp/helix.tar.xz -C /tmp
  cp "/tmp/helix-${HX_VER}-x86_64-linux/hx" "$LOCAL_BIN/"
  mkdir -p ~/.config/helix
  cp -r "/tmp/helix-${HX_VER}-x86_64-linux/runtime" ~/.config/helix/
  rm -rf /tmp/helix.tar.xz "/tmp/helix-${HX_VER}-x86_64-linux"
fi

# ═══════════════════════════════════════════════════════
# STAGE 3: DOTFILES (user-scoped)
# ═══════════════════════════════════════════════════════

log "Dotfiles"

cat > ~/.zshrc <<'EOF'
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export EDITOR=hx
export VISUAL=hx
export PAGER=less

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# git
alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gco='git checkout'
alias gb='git branch'
alias gl='git log --oneline --graph --decorate -20'
alias lg='lazygit'

# docker
alias d='docker'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlog='docker logs -f --tail 100'
alias dex='docker exec -it'

# ls / cd
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# utils
alias cat='bat --paging=never'
alias grep='rg'
alias top='btop'

[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh

eval "$(zoxide init zsh)"
alias cd='z'

eval "$(starship init zsh)"

alias zshrc='hx ~/.zshrc && source ~/.zshrc'
alias tmuxrc='hx ~/.tmux.conf'
alias hxrc='hx ~/.config/helix/config.toml'
EOF

cat > ~/.config/starship.toml <<'EOF'
add_newline = true
format = """
[╭─](bold green)$username[@](bold green)$hostname [in](bold) $directory$git_branch$git_status$git_state
[╰─](bold green)$character"""

[username]
show_always = true
style_user = "bold cyan"
format = "[$user]($style)"

[hostname]
ssh_only = false
style = "bold cyan"
format = "[$hostname]($style)"

[directory]
style = "bold yellow"
truncation_length = 4
truncate_to_repo = false

[git_branch]
symbol = " "
style = "bold purple"

[git_status]
style = "bold red"
ahead = "⇡${count}"
behind = "⇣${count}"
modified = "!${count}"
staged = "+${count}"
untracked = "?${count}"

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[cmd_duration]
min_time = 2000
format = "took [$duration]($style) "
EOF

cat > ~/.tmux.conf <<'EOF'
unbind C-b
set -g prefix C-a
bind C-a send-prefix

set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -g mouse on
set -g history-limit 50000
set -sg escape-time 0
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

bind r source-file ~/.tmux.conf \; display "tmux.conf reloaded"

bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

set -g status-position bottom
set -g status-style "bg=#1e1e2e,fg=#cdd6f4"
set -g status-left-length 40
set -g status-right-length 80
set -g status-left "#[fg=#89b4fa,bold] #S #[fg=#cdd6f4]│ "
set -g status-right "#[fg=#a6e3a1]#(cd #{pane_current_path}; git branch --show-current 2>/dev/null) #[fg=#cdd6f4]│ #[fg=#f9e2af]%H:%M #[fg=#cdd6f4]│ #[fg=#cba6f7]#h "
setw -g window-status-current-style "fg=#1e1e2e,bg=#89b4fa,bold"
setw -g window-status-current-format " #I:#W "
setw -g window-status-format " #I:#W "
EOF

cat > ~/.config/helix/config.toml <<'EOF'
theme = "catppuccin_mocha"

[editor]
line-number = "relative"
mouse = true
bufferline = "multiple"
color-modes = true
cursorline = true
auto-save = true
true-color = true

[editor.cursor-shape]
insert = "bar"
normal = "block"
select = "underline"

[editor.statusline]
left = ["mode", "spinner", "file-name", "file-modification-indicator"]
center = []
right = ["diagnostics", "selections", "position", "file-encoding", "file-type"]

[editor.lsp]
display-messages = true

[editor.indent-guides]
render = true
character = "╎"

[keys.normal]
C-s = ":w"
C-q = ":q"
EOF

log "Git config"
git config --global user.name "Alejo"
git config --global user.email "sergioa.camachoc@gmail.com"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.editor "hx"
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.line-numbers true
git config --global delta.syntax-theme "Monokai Extended"
git config --global merge.conflictstyle "diff3"
git config --global diff.colorMoved "default"

# ═══════════════════════════════════════════════════════
# STAGE 4: GITHUB SSH KEY
# ═══════════════════════════════════════════════════════

log "GitHub SSH key"
GH_KEY="$HOME/.ssh/github_ed25519"
if [[ ! -f "$GH_KEY" ]]; then
  ssh-keygen -t ed25519 -C "alejo@eccensia-server" -f "$GH_KEY" -N ""
else
  skip "GitHub key exists"
fi

ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null

if ! grep -q "^Host github.com$" ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config <<EOF

Host github.com
    HostName github.com
    User git
    IdentityFile $GH_KEY
    IdentitiesOnly yes
EOF
  chmod 600 ~/.ssh/config
fi

# ─── Auto-register key via gh CLI (if already authed) ───
log "Try gh auto-register key"
if gh auth status &>/dev/null; then
  KEY_TITLE="eccensia-server-$(hostname)"
  if gh ssh-key list 2>/dev/null | grep -q "$KEY_TITLE"; then
    skip "key '$KEY_TITLE' already on GitHub"
  else
    gh ssh-key add "$GH_KEY.pub" --title "$KEY_TITLE" \
      && log "Key registered to GitHub as '$KEY_TITLE'" \
      || warn "gh ssh-key add failed — paste manually"
  fi
else
  warn "gh not authed. Run: gh auth login --git-protocol ssh --web"
  warn "Then re-run this script to auto-register, OR paste pubkey manually."
fi

# ═══════════════════════════════════════════════════════
# STAGE 5: DEFAULT SHELL
# ═══════════════════════════════════════════════════════

log "Default shell → zsh"
if [[ "$SHELL" != "$(which zsh)" ]]; then
  sudo chsh -s "$(which zsh)" "$USER_NAME"
fi

# ═══════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════"
echo " SETUP DONE"
echo "════════════════════════════════════════════════════"
echo ""
echo " GitHub pubkey → paste at https://github.com/settings/keys"
echo ""
cat "$GH_KEY.pub"
echo ""
echo " Next:"
echo "   1. Add pubkey above to GitHub"
echo "   2. Test:  ssh -T git@github.com"
echo "   3. Logout/login (docker group + zsh take effect)"
echo "   4. tmux new -s main"
echo ""
