#!/bin/bash

# --- Colors ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
ORANGE='\033[1;33m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${ORANGE}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR ]${NC} $*" >&2; }

info "🐧 Initializing Linux host (Project Architecture) ..."

# 1. Update system and install dependencies
info "📦 Updating package list and installing dependencies..."
sudo apt-get update
sudo apt-get install -y curl wget git libnss3-tools

# 2. Install / Update Vagrant
if ! command -v vagrant &> /dev/null; then
    info "📦 Installing Vagrant via HashiCorp repository..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update && sudo apt-get install -y vagrant
else
    ok "✅ Vagrant already installed."
fi

# 3. Install hostmanager plugin
info "🔌 Configuring Vagrant plugins..."
if ! vagrant plugin list | grep -q "vagrant-hostmanager"; then
    vagrant plugin install vagrant-hostmanager
    ok "✅ vagrant-hostmanager plugin installed."
else
    ok "✅ vagrant-hostmanager plugin already present."
fi

# 4. Prompt for email for SSH
while true; do
    read -p "📧 Enter your GitHub email address: " EMAIL
    if [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$ ]]; then
        break
    else
        err "⚠️ Invalid email format."
    fi
done

# 5. SSH key management
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY" ]; then
    info "🔑 Generating Ed25519 key..."
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$SSH_KEY" -N ""

    info "------------------------------------------------------"
    echo "📋 ADD this key on GitHub (https://github.com/settings/keys):"
    echo -e "${GREEN}$(cat ${SSH_KEY}.pub)${NC}"
    echo -e "${BLUE}------------------------------------------------------${NC}"
else
    ok "✅ Existing SSH key."
fi

# 6. Configure SSH agent
# On Linux, we use ssh-add. To persist, one would usually add it to .bashrc or .zshrc
eval "$(ssh-agent -s)"
ssh-add "$SSH_KEY"

PROJECT_ENV_FILE="./.env"

# 7. SSL configuration (mkcert)
info "🔐 SSL configuration (mkcert)..."

if ! command -v mkcert &> /dev/null; then
    info "📦 mkcert not found. Installing..."
    # Download binary directly as it's often more recent than apt
    MKCERT_VERSION="v1.4.4"
    sudo wget https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-linux-amd64 -O /usr/local/bin/mkcert
    sudo chmod +x /usr/local/bin/mkcert
else
    ok "✅ mkcert already installed."
fi

mkcert -install

# --------------------------------------
# Load project.env
# --------------------------------------
if [ ! -f "$PROJECT_ENV_FILE" ]; then
  warn "❌ .env not found, using .env.example"
  cp .env.example .env
  info "📋 .env file created. Edit it and rerun the script."
  exit 1
fi

set -a
source "$PROJECT_ENV_FILE"
set +a

if [ -z "${VM_DOMAIN:-}" ]; then
  err "❌ VM_DOMAIN is not defined in .env"
  exit 1
fi

# 8. Generate certificates
mkdir -p ./infra/certs
info "Clear previous certs (if any)"
rm -f ./infra/certs/*

cd ./infra/certs
mkcert -cert-file wildcard.local.pem -key-file wildcard.local-key.pem "*.${VM_DOMAIN}" localhost 127.0.0.1
chmod 644 *.pem *.key

ok "✔ Wildcard certificates generated for *.${VM_DOMAIN}"

ok  "🎉 ALL DONE!"
info "👉 Next step: 'cd infra && vagrant up'"