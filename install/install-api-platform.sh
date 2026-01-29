#!/bin/bash
#
# install_api_platform.sh
#
# This script installs API Platform inside the Vagrant box.
# It assumes PHP, Composer, and Apache are already installed and configured.
# Run inside the VM: ./scripts/install_api_platform.sh
#
set -e

# ----------------------------
# Log helpers
# ----------------------------
info()  { printf "\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
ok()    { printf "\033[1;32m[ OK ]\033[0m %s\n"  "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[ERR ]\033[0m %s\n"  "$*" >&2; }

# Variables
PROJECT_DIR="/var/www/back"
echo "Installing API Platform..."

# Ensure the target directory exists and Laravel is already installed
if [ -d "${PROJECT_DIR}" ] && [ -f "${PROJECT_DIR}/composer.json" ]; then
  ok "✅  Detected existing Laravel project at ${PROJECT_DIR}"
else
  err "❌  No Laravel project found at ${PROJECT_DIR}. Run the Laravel installation script first."
  exit 1
fi

cd "$PROJECT_DIR" || exit

# Fonction pour vérifier si un programme est installé
is_installed() {
    command -v "$1" > /dev/null 2>&1
}

# Vérifier si Composer est installé
if ! is_installed composer; then
    echo "Composer is not installed. Please install Composer before proceeding."
    exit 1
fi

# Install API Platform via Composer
composer require api-platform/laravel > /dev/null 2>&1
php artisan api-platform:install > /dev/null 2>&1

ok "✅  Api Platform has been successfully installed in $PROJECT_DIR"
info "Happy building! 🚀"