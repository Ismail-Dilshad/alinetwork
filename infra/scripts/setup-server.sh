#!/usr/bin/env bash
# infra/scripts/setup-server.sh — one-time setup of a fresh Ubuntu 24.04 VPS (Hostinger KVM 8)
# Run as root:  bash setup-server.sh
# BEFORE running: make sure you can log in with an SSH key, because this
# script turns off password login and root login.
set -euo pipefail

DEPLOY_USER="deploy"
ROOT="/srv/alinetwork"

echo "==> Base system"
timedatectl set-timezone Asia/Baghdad
apt-get update && apt-get -y upgrade
apt-get install -y curl git ufw fail2ban unattended-upgrades rsync jq rclone \
  ca-certificates gnupg debian-keyring debian-archive-keyring apt-transport-https
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "==> Deploy user"
if ! id "$DEPLOY_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
  mkdir -p /home/$DEPLOY_USER/.ssh
  cp /root/.ssh/authorized_keys /home/$DEPLOY_USER/.ssh/
  chown -R $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER/.ssh
  chmod 700 /home/$DEPLOY_USER/.ssh && chmod 600 /home/$DEPLOY_USER/.ssh/authorized_keys
fi
# deploy may reload Caddy and nothing else as root
cat > /etc/sudoers.d/alinetwork <<EOF
$DEPLOY_USER ALL=(root) NOPASSWD: /usr/bin/systemctl reload caddy
EOF
chmod 440 /etc/sudoers.d/alinetwork

echo "==> SSH hardening"
cat > /etc/ssh/sshd_config.d/99-alinetwork.conf <<EOF
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
EOF
systemctl reload ssh

echo "==> Firewall (only SSH, HTTP, HTTPS)"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp   # HTTP/3
ufw --force enable
# Note: Docker can bypass ufw for published ports. That is safe here because
# every container port is bound to 127.0.0.1 in compose.server.yml.

echo "==> Docker"
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
usermod -aG docker $DEPLOY_USER

echo "==> Node.js 22 LTS, pnpm, PM2"
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi
corepack enable
npm install -g pm2
sudo -u $DEPLOY_USER bash -lc "corepack prepare pnpm@latest --activate && pm2 install pm2-logrotate"
env PATH=$PATH:/usr/bin pm2 startup systemd -u $DEPLOY_USER --hp /home/$DEPLOY_USER

echo "==> Caddy"
if ! command -v caddy &>/dev/null; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update && apt-get install -y caddy
fi

echo "==> Folders"
mkdir -p $ROOT/{infra,production/releases,staging/releases,data,backups/postgres}
mkdir -p $ROOT/secrets/{production,staging}
mkdir -p /var/log/alinetwork /var/log/caddy
chown -R $DEPLOY_USER:$DEPLOY_USER $ROOT /var/log/alinetwork
chown caddy:caddy /var/log/caddy
chmod 755 $ROOT $ROOT/production $ROOT/staging   # Caddy must read the console builds
chmod 700 $ROOT/secrets

echo "==> Daily backup at 03:15"
cat > /etc/cron.d/alinetwork-backup <<EOF
15 3 * * * $DEPLOY_USER $ROOT/infra/scripts/backup.sh >> /var/log/alinetwork/backup.log 2>&1
EOF

cat <<EOF

Done. Next steps (as user '$DEPLOY_USER'):
  1. Add this server's deploy key to GitHub (read-only):  ssh-keygen -t ed25519
  2. Copy the repo's infra/ folder to $ROOT/infra
  3. Fill in $ROOT/secrets/data.env and $ROOT/secrets/{production,staging}/*.env
     from infra/env/*.example  (chmod 600)
  4. docker compose -f $ROOT/infra/docker/compose.server.yml --env-file $ROOT/secrets/data.env up -d
  5. sudo ln -sf $ROOT/infra/caddy/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy
  6. $ROOT/infra/scripts/deploy.sh staging main
  7. $ROOT/infra/scripts/deploy.sh production v1.0.0
  8. pm2 save
EOF
