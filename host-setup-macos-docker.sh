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

info "🍏 Initialisation de l'hôte macOS (Architecture AkaStack) pour Docker ..."

# 1. Gestion des clés SSH
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY" ]; then
    info "🔑 Aucune clé SSH trouvée. Création d'une clé pour GitHub..."
    while true; do
        read -p "📧 Entrez votre email GitHub : " EMAIL
        if [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$ ]]; then
            break
        else
            err "⚠️ Format d'email invalide."
        fi
    done

    ssh-keygen -t ed25519 -C "$EMAIL" -f "$SSH_KEY" -N ""

    info "------------------------------------------------------"
    echo -e "${ORANGE}ACTION REQUISE :${NC}"
    echo "1. Copiez la clé publique ci-dessous :"
    echo -e "${GREEN}$(cat ${SSH_KEY}.pub)${NC}"
    echo "2. Ajoutez-la ici : https://github.com/settings/keys"
    echo "------------------------------------------------------"

    read -p "Appuyez sur [Entrée] une fois la clé ajoutée à GitHub..." CONFIRM
else
    ok "✅ Clé SSH existante trouvée."
fi

# 2. Configuration de l'agent SSH
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain "$SSH_KEY"

# 3. Clonage du dépôt Infra
INFRA_REPO="git@github.com:itakademy/AkaStack-infra.git"
INFRA_DIR="./infra"

if [ ! -d "$INFRA_DIR" ]; then
    info "📂 Clonage du dépôt infra..."
    git clone "$INFRA_REPO" "$INFRA_DIR"

    if [ -d "./.git" ]; then
        warn "⚠️ Nettoyage du .git racine pour isoler les briques..."
        rm -rf ./.git
    fi
else
    ok "✅ Répertoire infra déjà présent."
fi

# 4. Configuration Interactive & Création du .env
echo -e "\n${BLUE}⚙️  Configuration de l'environnement (Génération du .env)${NC}"
PROJECT_ENV_FILE="./docker/.env"

# Domaine
while true; do
    read -p "🔗 Domaine racine .local (ex: akastack.local) : " VAL_DOMAIN
    if [[ "$VAL_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.local$ ]]; then break; else err "⚠️ Doit finir par .local"; fi
done

# Mot de passe MySQL root
read -s -p "🔐 Mot de passe root MySQL : " VAL_MYSQL_ROOT
echo

# Écriture propre du fichier .env
cat <<EOF > "$PROJECT_ENV_FILE"
# Généré par host-setup-macos.sh
VM_DOMAIN=$VAL_DOMAIN
MYSQL_ROOT_PASSWORD=$VAL_MYSQL_ROOT
EOF

ok "✅ Fichier $PROJECT_ENV_FILE généré avec succès."

# 5. Installation des outils (Brew, Vagrant, Plugins, mkcert)
if ! command -v brew &> /dev/null; then
    info "📦 Installation de Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [[ $(uname -m) == "arm64" ]] && eval "$(/opt/homebrew/bin/brew shellenv)" || eval "$(/usr/local/bin/brew shellenv)"
fi

if ! command -v mkcert &> /dev/null; then
    brew install mkcert nss
fi
mkcert -install

# 6. Génération des Certificats SSL
mkdir -p "$INFRA_DIR/docker/certs"
rm -f "$INFRA_DIR/docker/certs/"*
info "🔐 Génération des certificats pour *.${VAL_DOMAIN}..."

(cd "$INFRA_DIR/docker/certs" && mkcert -cert-file wildcard.local.pem -key-file wildcard.local-key.pem "${VAL_DOMAIN}" "*.${VAL_DOMAIN}" localhost 127.0.0.1)

chmod 644 "$INFRA_DIR/docker/certs/"*.pem

ok "🎉 Configuration de l'hôte terminée !"
info "👉 Étape suivante : 'cd infra/docker && docker compose up -d'"
