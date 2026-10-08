#!/usr/bin/env bash
# Provisions (or re-provisions) a Draftmancer host on Ubuntu 24.04. Idempotent.
# Run as root from your machine:
#   ssh root@HOST "SITE_HOST=1-2-3-4.sslip.io bash -s" < deploy/hetzner/setup.sh
# SITE_HOST is the hostname Caddy gets a Let's Encrypt certificate for; the
# Cloudflare Worker (deploy/cloudflare/) proxies draftmancer.greggg230.com to it.
set -euo pipefail

: "${SITE_HOST:?set SITE_HOST}"
REPO="${REPO:-https://github.com/greggg230/Draftmancer.git}"
BRANCH="${BRANCH:-deploy/self-host}"
APP_DIR=/opt/draftmancer
export DEBIAN_FRONTEND=noninteractive

echo "==> packages"
apt-get update -q
apt-get install -y -q curl git ufw ca-certificates gnupg debian-keyring debian-archive-keyring apt-transport-https

if ! command -v node >/dev/null || ! node --version | grep -q '^v22\.'; then
	curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
	apt-get install -y -q nodejs
fi

if ! command -v caddy >/dev/null; then
	curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
	curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt > /etc/apt/sources.list.d/caddy-stable.list
	apt-get update -q
	apt-get install -y -q caddy
fi

echo "==> swap (the TypeScript + webpack build peaks above 2 GB)"
if ! swapon --show | grep -q /swapfile; then
	fallocate -l 2G /swapfile
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile
	grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> firewall"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "==> app user + checkout"
id draftmancer >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/draftmancer --shell /usr/sbin/nologin draftmancer
if [ ! -d "$APP_DIR/.git" ]; then
	git clone --filter=blob:none --branch "$BRANCH" "$REPO" "$APP_DIR"
	chown -R draftmancer:draftmancer "$APP_DIR"
fi

if [ ! -f /etc/draftmancer.env ]; then
	cat > /etc/draftmancer.env <<ENV
PORT=3000
NODE_ENV=production
SECRET_KEY=$(openssl rand -base64 24 | tr -d '/+=')
PERSISTENCE_LOCAL_PATH=/var/lib/draftmancer
DRAFTMANCER_AI_DOMAIN=http://127.0.0.1:9
ENV
	chmod 640 /etc/draftmancer.env
	chgrp draftmancer /etc/draftmancer.env
fi

cat > /etc/systemd/system/draftmancer.service <<'UNIT'
[Unit]
Description=Draftmancer
After=network-online.target
Wants=network-online.target

[Service]
User=draftmancer
WorkingDirectory=/opt/draftmancer
EnvironmentFile=/etc/draftmancer.env
ExecStart=/usr/bin/node --experimental-json-modules --max-old-space-size=1536 .
Restart=always
RestartSec=5
# SIGTERM makes the server dump sessions to PERSISTENCE_LOCAL_PATH (up to 30 s).
TimeoutStopSec=40

[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/caddy/Caddyfile <<CADDY
$SITE_HOST {
	reverse_proxy 127.0.0.1:3000
}
CADDY

systemctl daemon-reload
systemctl enable draftmancer caddy >/dev/null
systemctl reload-or-restart caddy

echo "==> build + start"
bash "$APP_DIR/deploy/hetzner/update.sh"
