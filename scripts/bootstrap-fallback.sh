#!/usr/bin/env bash
# Fallback bootstrap — run as ROOT if cloud-init failed or partial.
# Idempotent: safe to re-run. Skips steps already done.
#
# Usage (from local machine):
#   scp city/scripts/bootstrap-fallback.sh root@<ip>:/tmp/
#   ssh root@<ip> 'bash /tmp/bootstrap-fallback.sh'

set -euo pipefail

SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDIhSepfxlWMCrtbPuvqO0vwWyizrBODCWqvmRAh/3Mx alejo@bogota-main"
USER_NAME="alejo"

log() { echo -e "\n\033[1;34m[+] $*\033[0m"; }
skip() { echo -e "\033[1;33m[=] $* (already done)\033[0m"; }

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash $0"; exit 1
fi

# ─── Check cloud-init status ────────────────────────────
log "Cloud-init status"
cloud-init status --long || true

# ─── User ───────────────────────────────────────────────
log "User $USER_NAME"
if id "$USER_NAME" &>/dev/null; then
  skip "user exists"
else
  useradd -m -s /bin/bash -G sudo "$USER_NAME"
  echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USER_NAME"
  chmod 0440 "/etc/sudoers.d/$USER_NAME"
fi

mkdir -p "/home/$USER_NAME/.ssh"
chmod 700 "/home/$USER_NAME/.ssh"
if ! grep -qF "$SSH_PUBKEY" "/home/$USER_NAME/.ssh/authorized_keys" 2>/dev/null; then
  echo "$SSH_PUBKEY" >> "/home/$USER_NAME/.ssh/authorized_keys"
fi
chmod 600 "/home/$USER_NAME/.ssh/authorized_keys"
chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.ssh"

# ─── System ─────────────────────────────────────────────
log "Timezone + locale"
timedatectl set-timezone America/Bogota || true
locale-gen en_US.UTF-8 || true

log "APT update + base packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ufw fail2ban htop curl git vim ca-certificates gnupg \
  lsb-release unattended-upgrades apt-listchanges

# ─── SSH hardening ──────────────────────────────────────
log "SSH hardening"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# ─── UFW ────────────────────────────────────────────────
log "UFW firewall"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# ─── fail2ban ───────────────────────────────────────────
log "fail2ban"
cat > /etc/fail2ban/jail.local <<'EOF'
[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 3600
findtime = 600
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

# ─── Auto updates ───────────────────────────────────────
log "Unattended-upgrades"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# ─── Sysctl ─────────────────────────────────────────────
log "Sysctl tuning"
cat > /etc/sysctl.d/99-tuning.conf <<'EOF'
vm.swappiness=10
vm.overcommit_memory=1
net.ipv4.tcp_fin_timeout=15
net.core.somaxconn=1024
EOF
sysctl --system >/dev/null

# ─── Swap ───────────────────────────────────────────────
log "Swap 2GB"
if [[ -f /swapfile ]]; then
  skip "swapfile exists"
else
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# ─── Docker ─────────────────────────────────────────────
log "Docker"
if command -v docker &>/dev/null; then
  skip "docker installed"
else
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  ARCH=$(dpkg --print-architecture)
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

usermod -aG docker "$USER_NAME"

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
systemctl enable --now docker
systemctl restart docker

# ─── App dir ────────────────────────────────────────────
log "App directory"
mkdir -p /opt/apps
chown "$USER_NAME:$USER_NAME" /opt/apps

# ─── Done ───────────────────────────────────────────────
touch /var/lib/cloud-init-success
log "DONE. Disconnect root, reconnect: ssh $USER_NAME@<ip>"
log "Then run post-creation.sh as $USER_NAME for dev env."
