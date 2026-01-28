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
PROJECT_DIR="$STACK_ROOT/back"
PROJECT_ENV_FILE="$STACK_ROOT/project.env"
ENV_FILE="$PROJECT_DIR/.env"

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
# Backend presence
# ----------------------------
if [ -d "$PROJECT_DIR/.git" ] && is_submodule "$PROJECT_DIR"; then
  ok "Backend is a Git submodule"
  cd "$PROJECT_DIR"
elif [ ! -d "$PROJECT_DIR" ]; then
  warn "No backend found — creating new Laravel backend"
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"
  composer create-project laravel/laravel .
else
  err "Directory back/ exists but is NOT a submodule — refusing to continue"
  exit 1
fi

# ----------------------------
# Ensure Laravel exists
# ----------------------------
if [ ! -f artisan ]; then
  info "Installing Laravel"
  composer create-project laravel/laravel .
else
  ok "Laravel detected"
fi

# ----------------------------
# Install dependencies
# ----------------------------
if [ ! -f vendor/autoload.php ]; then
  composer install
fi

composer require barryvdh/laravel-debugbar --dev
composer require filament/filament:^4.0 filament/widgets:^4.0 beier/filament-pages binarytorch/larecipe mongodb/laravel-mongodb laravel/horizon

# ----------------------------
# .env
# ----------------------------
if [ ! -f "$ENV_FILE" ]; then
  cp .env.example .env
fi

cp "$ENV_FILE" "$ENV_FILE.bak"

for var in APP_NAME APP_ENV APP_DEBUG APP_URL DB_HOST DB_DATABASE DB_USERNAME DB_PASSWORD REDIS_HOST MONGODB_URI; do
  sed -i "s|^$var=.*|$var=${!var}|" "$ENV_FILE" || echo "$var=${!var}" >> "$ENV_FILE"
done

# ----------------------------
# Database
# ----------------------------
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
CREATE DATABASE IF NOT EXISTS \`$DB_DATABASE\`
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
"

php artisan key:generate
php artisan migrate --force
php artisan horizon:install
php artisan filament:install --panels

# ----------------------------
# Apache
# ----------------------------
VHOST="back.${PROJECT_DOMAIN}"
DOCROOT="$PROJECT_DIR/public"

a2enmod proxy_fcgi rewrite ssl >/dev/null

cat > /etc/apache2/sites-available/001-back.conf <<EOF
<VirtualHost *:80>
  ServerName $VHOST
  Redirect permanent / https://$VHOST/
</VirtualHost>
EOF

cat > /etc/apache2/sites-available/001-back-ssl.conf <<EOF
<VirtualHost *:443>
  ServerName $VHOST
  DocumentRoot $DOCROOT

  <Directory $DOCROOT>
    AllowOverride All
    Require all granted
  </Directory>

  SSLEngine on
  SSLCertificateFile /etc/ssl/orizon/orizon.dev.pem
  SSLCertificateKeyFile /etc/ssl/orizon/orizon.dev.key

  <FilesMatch \.php$>
    SetHandler "proxy:unix:/run/php/php8.4-fpm.sock|fcgi://localhost"
  </FilesMatch>
</VirtualHost>
EOF

a2ensite 001-back 001-back-ssl
systemctl reload apache2

# ----------------------------
# Supervisor
# ----------------------------
if ! command -v supervisorctl >/dev/null; then
  apt install -y supervisor
fi

systemctl enable supervisor
systemctl restart supervisor

ok "Backend ready at https://$VHOST"
