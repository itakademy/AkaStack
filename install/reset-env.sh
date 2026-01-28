#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[ OK ]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERR ]\033[0m $*" >&2; }

STACK="/var/www/project"
BACK="$STACK/back"
FRONT="$STACK/front"

[ -f "$STACK/project.env" ] || { err "Missing project.env"; exit 1; }
source "$STACK/project.env"

ROLLBACK_FILE="$STACK/.last-good-state"

warn "This will reset client + optionally rollback back/front Git state"
read -rp "Type RESET to continue: " c
[ "$c" = "RESET" ] || exit 1

# ----------------------------
# Save current state
# ----------------------------
cd "$STACK"
git submodule status > "$ROLLBACK_FILE"
ok "Saved current Git state"

# ----------------------------
# Ask rollback
# ----------------------------
read -rp "Rollback to last saved state? (yes/no): " r

if [ "$r" = "yes" ] && [ -f "$ROLLBACK_FILE" ]; then
  info "Rolling back submodules"
  while read -r line; do
    sha=$(echo "$line" | awk '{print $1}')
    path=$(echo "$line" | awk '{print $2}')
    (cd "$STACK/$path" && git fetch && git checkout "$sha")
  done < "$ROLLBACK_FILE"
fi

# ----------------------------
# Stop runtime
# ----------------------------
pm2 delete all || true
cd "$BACK"
php artisan horizon:terminate || true

# ----------------------------
# Clear Laravel
# ----------------------------
php artisan down || true
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan optimize:clear
rm -rf storage/framework/* bootstrap/cache/*

# ----------------------------
# Reset databases
# ----------------------------
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS \`$DB_DATABASE\`; CREATE DATABASE \`$DB_DATABASE\`;"
mongosh "$MONGODB_URI" --eval "db.dropDatabase()"
redis-cli -a "$REDIS_PASSWORD" FLUSHALL

# ----------------------------
# Rebuild backend
# ----------------------------
php artisan migrate --force
php artisan db:seed || true
php artisan key:generate --force
php artisan horizon:install
php artisan up

# ----------------------------
# Rebuild frontend
# ----------------------------
if [ -f "$FRONT/package.json" ]; then
  cd "$FRONT"
  rm -rf .next node_modules
  npm install
  npm run build
  pm2 start npm --name nextjs-front -- start
fi

pm2 save

ok "Reset + rollback completed"
