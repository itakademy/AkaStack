#!/usr/bin/env bash
set -e

PROJECT_ENV_FILE="./project.env"

echo "======================================"
echo " Generating HTTPS certificates (mkcert)"
echo "======================================"

# --------------------------------------
# Load project.env
# --------------------------------------
if [ ! -f "$PROJECT_ENV_FILE" ]; then
  echo "❌ project.env not found"
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$PROJECT_ENV_FILE"
set +a

if [ -z "${PROJECT_DOMAIN:-}" ]; then
  echo "❌ PROJECT_DOMAIN is not defined in project.env"
  exit 1
fi

# --------------------------------------
# Check mkcert
# --------------------------------------
if ! command -v mkcert >/dev/null 2>&1; then
  echo "❌ mkcert is not installed"
  echo "→ https://github.com/FiloSottile/mkcert"
  exit 1
fi

# --------------------------------------
# Domains to generate
# --------------------------------------
DOMAINS=(
  "www.${PROJECT_DOMAIN}"
  "back.${PROJECT_DOMAIN}"
  "redis.${PROJECT_DOMAIN}"
  "mail.${PROJECT_DOMAIN}"
  "mongo.${PROJECT_DOMAIN}"
  "swagger.${PROJECT_DOMAIN}"
  "${PROJECT_DOMAIN}"
)

echo "▶ Domains:"installed
for d in "${DOMAINS[@]}"; do
  echo "  - $d"
done

sudo mkdir -p certs/
echo "Clear previous certs (if any)"
sudo rm -f certs/*
# --------------------------------------
# Generate certs
# --------------------------------------
cd certs
sudo mkcert "${DOMAINS[@]}"
sudo mv *-key.pem orizon.dev.key
sudo mv *.pem orizon.dev.pem
sudo chmod -R 777 *.pem
sudo chmod -R 777 *.key

echo "✔ Certificates generated successfully in ./certs directory"
echo "✔ Domain base: ${PROJECT_DOMAIN}"
