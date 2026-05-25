#!/usr/bin/env bash
# Dev environment setup — run as USER alejo (NOT root) after bootstrap.
# Installs: zsh + starship, tmux, helix, modern CLI tools, Claude Code, dotfiles.
# Idempotent.
#
# Usage:
#   scp city/scripts/post-creation.sh alejo@<ip>:~/
#   ssh alejo@<ip> 'bash ~/post-creation.sh'

set -euo pipefail

log() { echo -e "\n\033[1;34m[+] $*\033[0m"; }
skip() { echo -e "\033[1;33m[=] $* (already done)\033[0m"; }

if [[ $EUID -eq 0 ]]; then
  echo "Do NOT run as root. Run as alejo."; exit 1
fi

# ─── APT packages ───────────────────────────────────────
log "Base CLI tools (apt)"
sudo apt-get update -y
sudo apt-get install -y \
  zsh tmux \
  ripgrep fd-find bat fzf \
  build-essential pkg-config \
  unzip jq wget \
  python3-pip python3-venv \
  nodejs npm

# Symlink fd (Debian names it fdfind)
[[ -e ~/.local/bin/fd ]] || { mkdir -p ~/.local/bin && ln -sf "$(which fdfind)" ~/.local/bin/fd; }
# Symlink bat (Debian names it batcat)
[[ -e ~/.local/bin/bat ]] || ln -sf "$(which batcat)" ~/.local/bin/bat

# ─── eza ────────────────────────────────────────────────
log "eza (modern ls)"
if ! command -v eza &>/dev/null; then
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  sudo apt-get update -y
  sudo apt-get install -y eza
else
  skip "eza"
fi

# ─── starship prompt ────────────────────────────────────
log "starship"
if ! command -v starship &>/dev/null; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
else
  skip "starship"
fi

# ─── zoxide ─────────────────────────────────────────────
log "zoxide"
if ! command -v zoxide &>/dev/null; then
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
else
  skip "zoxide"
fi

# ─── lazygit ────────────────────────────────────────────
log "lazygit"
if ! command -v lazygit &>/dev/null; then
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
  curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
  sudo install /tmp/lazygit /usr/local/bin
  rm /tmp/lazygit /tmp/lazygit.tar.gz
else
  skip "lazygit"
fi

# ─── btop ───────────────────────────────────────────────
log "btop"
sudo apt-get install -y btop || skip "btop unavailable on this release"

# ─── Helix editor ───────────────────────────────────────
log "helix"
if ! command -v hx &>/dev/null; then
  sudo add-apt-repository -y ppa:maveonair/helix-editor
  sudo apt-get update -y
  sudo apt-get install -y helix
else
  skip "helix"
fi

# ─── delta (git pager) ──────────────────────────────────
log "git-delta"
if ! command -v delta &>/dev/null; then
  DELTA_VERSION=$(curl -s "https://api.github.com/repos/dandavison/delta/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
  curl -Lo /tmp/delta.deb "https://github.com/dandavison/delta/releases/latest/download/git-delta_${DELTA_VERSION}_amd64.deb"
  sudo dpkg -i /tmp/delta.deb
  rm /tmp/delta.deb
else
  skip "delta"
fi

# ─── Claude Code ────────────────────────────────────────
log "Claude Code"
if ! command -v claude &>/dev/null; then
  sudo npm install -g @anthropic-ai/claude-code
else
  skip "claude code"
fi

# ─── Configs ────────────────────────────────────────────
log "Dotfiles"

mkdir -p ~/.config/{helix,starship}

# ── .zshrc ──
cat > ~/.zshrc <<'EOF'
# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Paths
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export EDITOR=hx
export VISUAL=hx
export PAGER=less

# Aliases — git
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

# Aliases — docker
alias d='docker'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlog='docker logs -f --tail 100'
alias dex='docker exec -it'

# Aliases — ls/cd
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Aliases — utils
alias cat='bat --paging=never'
alias grep='rg'
alias top='btop'
alias hx='helix'

# fzf
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh

# zoxide
eval "$(zoxide init zsh)"
alias cd='z'

# starship
eval "$(starship init zsh)"

# Quick edit configs
alias zshrc='hx ~/.zshrc && source ~/.zshrc'
alias tmuxrc='hx ~/.tmux.conf'
alias hxrc='hx ~/.config/helix/config.toml'
EOF

# ── starship ──
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

# ── tmux ──
cat > ~/.tmux.conf <<'EOF'
# Prefix: Ctrl-a (easier than Ctrl-b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Sane defaults
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -g mouse on
set -g history-limit 50000
set -sg escape-time 0
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

# Reload config
bind r source-file ~/.tmux.conf \; display "tmux.conf reloaded"

# Split: | and -, in current dir
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Vim-style pane nav
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Resize panes
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Status bar
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

# ── helix ──
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

# ── git config ──
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

# ─── GitHub SSH key ─────────────────────────────────────
log "GitHub SSH key"
GH_KEY="$HOME/.ssh/github_ed25519"
if [[ -f "$GH_KEY" ]]; then
  skip "GitHub key exists"
else
  ssh-keygen -t ed25519 -C "alejo@eccensia-server" -f "$GH_KEY" -N ""
fi

# Add github.com to known_hosts (avoid prompt on first clone)
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null

# SSH config for GitHub
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

# ─── Workspace ──────────────────────────────────────────
log "Workspace dir"
mkdir -p "$HOME/workspace"

# ─── Default shell zsh ──────────────────────────────────
log "Default shell → zsh"
if [[ "$SHELL" != "$(which zsh)" ]]; then
  sudo chsh -s "$(which zsh)" "$USER"
fi

# ─── Final output ───────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════"
echo " SETUP DONE"
echo "════════════════════════════════════════════════════"
echo ""
echo " GitHub pubkey (add at https://github.com/settings/keys):"
echo ""
cat "$GH_KEY.pub"
echo ""
echo " Next:"
echo "   1. Add pubkey above to GitHub"
echo "   2. Test:  ssh -T git@github.com"
echo "   3. Clone repos into ~/workspace/"
echo "   4. exec zsh   (or logout/login)"
echo "   5. tmux new -s main"
echo ""
