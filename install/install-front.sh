#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ----------------------------
# Log helpers
# ----------------------------
info()  { printf "\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
ok()    { printf "\033[1;32m[ OK ]\033[0m %s\n"  "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[ERR ]\033[0m %s\n"  "$*" >&2; }

# ----------------------------
# Paths
# ----------------------------
STACK_ROOT="/var/www/project"
PROJECT_DIR="$STACK_ROOT/front"
PROJECT_ENV_FILE="$STACK_ROOT/project.env"

# ----------------------------
# Load stack environment
# ----------------------------
if [ -f "$PROJECT_ENV_FILE" ]; then
  set -a
  source "$PROJECT_ENV_FILE"
  set +a
  ok "Loaded $PROJECT_ENV_FILE"
else
  err "Missing $PROJECT_ENV_FILE"
  exit 1
fi

# ----------------------------
# Git helpers
# ----------------------------
is_submodule() {
  git submodule status -- "$1" &>/dev/null
}

cd "$STACK_ROOT"

# ----------------------------
# Frontend presence
# ----------------------------
if [ -d "$PROJECT_DIR/.git" ] && is_submodule "$PROJECT_DIR"; then
  ok "Frontend is a Git submodule"
  cd "$PROJECT_DIR"
elif [ ! -d "$PROJECT_DIR" ]; then
  warn "No frontend found — creating new Next.js frontend"
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"
  npx create-next-app@latest . --ts --tailwind --eslint --src-dir --app --no-git
else
  err "Directory front/ exists but is NOT a submodule — refusing to continue"
  exit 1
fi

# ----------------------------
# Install deps
# ----------------------------
if [ ! -f package.json ]; then
  err "No package.json — not a Node frontend"
  exit 1
fi

npm install

# ----------------------------
# Build
# ----------------------------
npm run build

# ----------------------------
# PM2
# ----------------------------
if ! command -v pm2 >/dev/null; then
  npm install -g pm2
fi

pm2 delete nextjs-front 2>/dev/null || true
pm2 start npm --name nextjs-front -- start
pm2 save
pm2 startup systemd -u root --hp /root >/dev/null

# ----------------------------
# Apache
# ----------------------------
VHOST="www.${PROJECT_DOMAIN}"

a2enmod proxy proxy_http proxy_wstunnel ssl >/dev/null

cat > /etc/apache2/sites-available/100-front.conf <<EOF
<VirtualHost *:80>
  ServerName $VHOST
  Redirect permanent / https://$VHOST/
</VirtualHost>
EOF

cat > /etc/apache2/sites-available/100-front-ssl.conf <<EOF
<VirtualHost *:443>
  ServerName $VHOST

  SSLEngine on
  SSLCertificateFile /etc/ssl/orizon/orizon.dev.pem
  SSLCertificateKeyFile /etc/ssl/orizon/orizon.dev.key

  ProxyPreserveHost On
  ProxyPass / http://127.0.0.1:3000/
  ProxyPassReverse / http://127.0.0.1:3000/
</VirtualHost>
EOF

a2ensite 100-front 100-front-ssl
systemctl reload apache2

# ----------------------------
# Hosts
# ----------------------------
grep -q "$VHOST" /etc/hosts || echo "127.0.0.1 $VHOST" >> /etc/hosts

ok "Frontend ready at https://$VHOST"
