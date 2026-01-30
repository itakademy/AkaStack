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

info "🍏 Initializing macOS host (Project Architecture) ..."

# 1. SSH Key Management
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY" ]; then
    info "🔑 No SSH key found. Let's create one for GitHub."
    while true; do
        read -p "📧 Enter your GitHub email address: " EMAIL
        if [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$ ]]; then
            break
        else
            err "⚠️ Invalid email format."
        fi
    done

    ssh-keygen -t ed25519 -C "$EMAIL" -f "$SSH_KEY" -N ""

    info "------------------------------------------------------"
    echo -e "${ORANGE}ACTION REQUIRED:${NC}"
    echo "1. Copy the public key below:"
    echo -e "${GREEN}$(cat ${SSH_KEY}.pub)${NC}"
    echo "2. Paste it in your GitHub settings: https://github.com/settings/keys"
    echo "------------------------------------------------------"

    read -p "Press [Enter] once you have added the key to GitHub..." CONFIRM
else
    ok "✅ Existing SSH key found."
fi

# 2. Configure SSH agent and Keychain
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain "$SSH_KEY"

# 3. Clone Infra Repository
INFRA_REPO="git@github.com:itakademy/AkaStack-infra.git"
INFRA_DIR="./infra"

if [ ! -d "$INFRA_DIR" ]; then
    info "📂 Cloning infra repository..."
    git clone "$INFRA_REPO" "$INFRA_DIR"

    if [ -d "./.git" ]; then
        warn "⚠️ Removing .git from the parent directory to isolate project bricks..."
        rm -rf ./.git
    fi
else
    ok "✅ Infra directory already exists."
fi

# 4. Interactive Configuration (Domain & IP)
echo -e "${BLUE}🌐 Network Configuration${NC}"

# Domain prompt
while true; do
    read -p "🔗 Enter your desired local root domain (ex: project.local) : " VM_DOMAIN
    if [[ "$VM_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.local$ ]]; then
        break
    else
        err "⚠️ Domain must end with .local"
    fi
done

# IP prompt
while true; do
    read -p "🌐 Enter the static IP for the VM (ex: 192.168.56.10) : " VM_IP
    if [[ "$VM_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        break
    else
        err "⚠️ Invalid IP address format."
    fi
done

# Write/Update variables in the root .env file
PROJECT_ENV_FILE="./.env"
# Clean existing and write new
sed -i '' "/^VM_DOMAIN=/d" "$PROJECT_ENV_FILE" 2>/dev/null
sed -i '' "/^VM_IP=/d" "$PROJECT_ENV_FILE" 2>/dev/null
echo "VM_DOMAIN=$VM_DOMAIN" >> "$PROJECT_ENV_FILE"
echo "VM_IP=$VM_IP" >> "$PROJECT_ENV_FILE"

ok "✅ Configuration saved to .env (Domain: $VM_DOMAIN, IP: $VM_IP)"

# 5. Tooling: Homebrew, Vagrant & Plugins
if ! command -v brew &> /dev/null; then
    info "📦 Homebrew not detected. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [[ $(uname -m) == "arm64" ]] && eval "$(/opt/homebrew/bin/brew shellenv)" || eval "$(/usr/local/bin/brew shellenv)"
fi

if ! command -v vagrant &> /dev/null; then
    brew install --cask vagrant
fi

if ! vagrant plugin list | grep -q "vagrant-hostmanager"; then
    info "🔌 Installing vagrant-hostmanager..."
    vagrant plugin install vagrant-hostmanager
fi

# 6. SSL Configuration (mkcert)
if ! command -v mkcert &> /dev/null; then
    info "📦 Installing mkcert..."
    brew install mkcert nss
fi
mkcert -install

# 7. Generate Certificates
mkdir -p "$INFRA_DIR/certs"
rm -f "$INFRA_DIR/certs/"*
info "🔐 Generating Wildcard certificates for *.${VM_DOMAIN}..."

(cd "$INFRA_DIR/certs" && mkcert -cert-file wildcard.local.pem -key-file wildcard.local-key.pem "*.${VM_DOMAIN}" localhost 127.0.0.1 "$VM_IP")

chmod 644 "$INFRA_DIR/certs/"*.pem

ok "🎉 ALL DONE!"
info "👉 Next step: 'cd infra && vagrant up'"