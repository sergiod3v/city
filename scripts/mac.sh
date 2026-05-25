#!/usr/bin/env bash
# Mac SSH key setup for Hetzner VPS.
# Generates ed25519 key with passphrase, loads into keychain, configures SSH client.
#
# Usage:
#   bash city/scripts/mac.sh [server_ip]
#
# server_ip optional — can be added later by editing ~/.ssh/config

set -euo pipefail

KEY_NAME="hetzner_main"
KEY_PATH="$HOME/.ssh/$KEY_NAME"
COMMENT="alejo@mac"
SERVER_IP="${1:-<SERVER_IP>}"

log() { echo -e "\n\033[1;34m[+] $*\033[0m"; }
skip() { echo -e "\033[1;33m[=] $*\033[0m"; }

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Run on macOS only."; exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# ─── Generate key ───────────────────────────────────────
if [[ -f "$KEY_PATH" ]]; then
  skip "Key exists: $KEY_PATH (skipping generation)"
else
  log "Generating ed25519 key — you'll be prompted for passphrase"
  ssh-keygen -t ed25519 -C "$COMMENT" -f "$KEY_PATH"
fi

chmod 600 "$KEY_PATH"
chmod 644 "$KEY_PATH.pub"

# ─── Load into macOS keychain (passphrase cached) ───────
log "Adding key to macOS keychain (passphrase prompt once)"
eval "$(ssh-agent -s)" >/dev/null
ssh-add --apple-use-keychain "$KEY_PATH"

# ─── ~/.ssh/config ──────────────────────────────────────
log "Configuring ~/.ssh/config"
touch "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

if grep -q "^Host hetzner$" "$HOME/.ssh/config"; then
  skip "Host 'hetzner' already in config"
else
  cat >> "$HOME/.ssh/config" <<EOF

Host hetzner
    HostName $SERVER_IP
    User alejo
    IdentityFile $KEY_PATH
    IdentitiesOnly yes
    UseKeychain yes
    AddKeysToAgent yes
EOF
  log "Added 'hetzner' host. Edit HostName if IP changes."
fi

# ─── Copy pubkey to clipboard ───────────────────────────
log "Public key copied to clipboard"
pbcopy < "$KEY_PATH.pub"

echo ""
echo "────────────────────────────────────────────────────"
echo "Public key:"
echo ""
cat "$KEY_PATH.pub"
echo ""
echo "────────────────────────────────────────────────────"
echo ""
echo "Next steps:"
echo "  1. Paste pubkey (clipboard) → Hetzner Console → SSH Keys → Add"
echo "     OR add to city/setup.yaml ssh_authorized_keys: list"
echo "  2. After server launch, update ~/.ssh/config HostName with real IP"
echo "  3. Connect: ssh hetzner"
echo ""
echo "If server already running, push key live:"
echo "  ssh-copy-id -i $KEY_PATH.pub alejo@<server-ip>"
