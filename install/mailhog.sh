#!/usr/bin/env bash
set -e

# ensure root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo $0 ..."
  exit 1
fi

echo "======================================"
echo " Installing MailHog (Go official build)"
echo "======================================"

# -------- Config --------
PROJECT_SRC_DIR="/var/www/project"
ENV_FILE="$PROJECT_SRC_DIR/project.env"

MAILHOG_BIN="/usr/local/bin/mailhog"
SERVICE_FILE="/etc/systemd/system/mailhog.service"
MARKER_FILE="$PROJECT_SRC_DIR/.mailhog.installed"

GO_VERSION="1.24.0"
ARCH="$(uname -m)"
GO_TARBALL=""

# -------- Load .env --------
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
  echo "Loaded env from $ENV_FILE"
else
  echo "ERROR: $ENV_FILE not found"
  exit 1
fi

# -------- Detect arch --------
case "$ARCH" in
  x86_64)   GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz" ;;
  aarch64|arm64) GO_TARBALL="go${GO_VERSION}.linux-arm64.tar.gz" ;;
  *) echo "Unsupported arch $ARCH"; exit 1 ;;
esac

# -------- Install Go --------
echo "Installing Go $GO_VERSION"
cd /tmp
curl -fsSL "https://go.dev/dl/${GO_TARBALL}" -o /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz

export PATH="/usr/local/go/bin:$PATH"
export GOPATH="/opt/go"

mkdir -p "$GOPATH/bin"

echo "Go version:"
/usr/local/go/bin/go version

# -------- Build MailHog --------
echo "Building MailHog"
/usr/local/go/bin/go install github.com/mailhog/MailHog@latest

sudo cp "$GOPATH/bin/MailHog" "$MAILHOG_BIN"
sudo chmod +x "$MAILHOG_BIN"

# -------- systemd service --------
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=MailHog
After=network.target

[Service]
ExecStart=/usr/local/bin/mailhog -ui-bind-addr=0.0.0.0:8025 -smtp-bind-addr=127.0.0.1:1025
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mailhog
sudo systemctl restart mailhog

sleep 2

ss -lntp | grep -q ":8025" || {
  echo "MailHog not listening on 8025"
  systemctl status mailhog --no-pager
  exit 1
}

# -------- Apache --------

echo "Configuring Apache"

sudo tee /etc/apache2/sites-available/500-mailhog.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName mail.${PROJECT_DOMAIN}
    Redirect permanent / https://mail.${PROJECT_DOMAIN}/
</VirtualHost>
EOF

sudo tee /etc/apache2/sites-available/500-mailhog-ssl.conf > /dev/null <<EOF
<VirtualHost *:443>
    ServerName mail.${PROJECT_DOMAIN}

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/orizon.dev.pem
    SSLCertificateKeyFile /etc/apache2/ssl/orizon.dev.key

    ProxyPreserveHost On
    ProxyPass        / http://127.0.0.1:8025/
    ProxyPassReverse / http://127.0.0.1:8025/

    <Location />
        Require ip 127.0.0.1 192.168.56.0/24
    </Location>
</VirtualHost>
EOF

sudo a2enmod proxy proxy_http ssl headers rewrite
sudo a2ensite 500-mailhog
sudo a2ensite 500-mailhog-ssl
sudo systemctl reload apache2

touch "$MARKER_FILE"

echo "======================================"
echo " MailHog is running"
echo " Web UI : https://mail.${PROJECT_DOMAIN}"
echo " SMTP   : 127.0.0.1:1025"
echo "======================================"
