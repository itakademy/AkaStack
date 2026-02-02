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

info "🐧 Initialisation de l'hôte Linux (Architecture AkaStack) ..."

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

# 2. Configuration de l'agent SSH (session actuelle)
eval "$(ssh-agent -s)"
ssh-add "$SSH_KEY"

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
PROJECT_ENV_FILE="./.env"

while true; do
    read -p "🔗 Domaine racine .local (ex: akastack.local) : " VAL_DOMAIN
    if [[ "$VAL_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.local$ ]]; then break; else err "⚠️ Doit finir par .local"; fi
done

while true; do
    read -p "🌐 Adresse IP statique (ex: 192.168.56.10) : " VAL_IP
    if [[ "$VAL_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then break; else err "⚠️ Format IP invalide"; fi
done

read -p "💻 Nombre de CPUs (conseil: 2) [2] : " VAL_CPUS
VAL_CPUS=${VAL_CPUS:-2}

read -p "🧠 Mémoire RAM en Mo (conseil: 4096) [4096] : " VAL_RAM
VAL_RAM=${VAL_RAM:-4096}

read -s -p "🔐 Mot de passe root MySQL : " VAL_MYSQL_ROOT
echo

cat <<EOF > "$PROJECT_ENV_FILE"
# Généré par host-setup-linux.sh
VM_DOMAIN=$VAL_DOMAIN
VM_IP=$VAL_IP
VM_CPUS=$VAL_CPUS
VM_MEMORY=$VAL_RAM
MYSQL_ROOT_PASSWORD=$VAL_MYSQL_ROOT
EOF

ok "✅ Fichier $PROJECT_ENV_FILE généré."

# 5. Installation des outils (Vagrant & mkcert)
sudo apt-get update && sudo apt-get install -y wget curl git libnss3-tools

if ! command -v vagrant &> /dev/null; then
    info "📦 Installation de Vagrant (Dépôt HashiCorp)..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update && sudo apt-get install -y vagrant
fi

if ! vagrant plugin list | grep -q "vagrant-hostmanager"; then
    info "🔌 Installation du plugin hostmanager..."
    vagrant plugin install vagrant-hostmanager
fi

if ! command -v mkcert &> /dev/null; then
    info "📦 Installation de mkcert..."
    VERSION="v1.4.4"
    wget https://github.com/FiloSottile/mkcert/releases/download/${VERSION}/mkcert-${VERSION}-linux-amd64 -O mkcert
    chmod +x mkcert
    sudo mv mkcert /usr/local/bin/
fi
mkcert -install

# 6. Génération des Certificats SSL
mkdir -p "$INFRA_DIR/certs"
rm -f "$INFRA_DIR/certs/"*
info "🔐 Génération des certificats pour *.${VAL_DOMAIN}..."

(cd "$INFRA_DIR/certs" && mkcert -cert-file wildcard.local.pem -key-file wildcard.local-key.pem "${VAL_DOMAIN}" "*.${VAL_DOMAIN}" localhost 127.0.0.1 "$VAL_IP")

ok "🎉 Configuration Linux terminée !"
info "👉 Étape suivante : 'cd infra && vagrant up'"
