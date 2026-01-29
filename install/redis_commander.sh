#!/usr/bin/env bash

set -e

# ensure root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo $0 ..."
  exit 1
fi

echo "======================================"
echo " Installing Redis Commander"
echo "======================================"

# --------------------------------------
# Prerequisites
# --------------------------------------
if ! command -v node >/dev/null 2>&1; then
  echo "❌ Node.js is required but not installed."
  exit 1
fi

if ! command -v redis-server >/dev/null 2>&1; then
  echo "❌ Redis server is required but not installed."
  exit 1
fi

# shellcheck disable=SC1090
set -a
source /var/www/stack/project.env
set +a

# --------------------------------------
# Install redis-commander (global)
# --------------------------------------
if ! command -v redis-commander >/dev/null 2>&1; then
  echo "▶ Installing redis-commander via npm"
  npm install -g redis-commander
else
  echo "✔ redis-commander already installed"
fi

# --------------------------------------
# Create systemd service
# --------------------------------------
SERVICE_FILE="/etc/systemd/system/redis-commander.service"

if [ ! -f "$SERVICE_FILE" ]; then
  echo "▶ Creating systemd service"

  cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Redis Commander
After=network.target redis-server.service
Requires=redis-server.service

[Service]
ExecStart=/usr/bin/redis-commander \
  --redis-host 127.0.0.1 \
  --redis-port 6379 \
  --port 8081 \
  --no-open
Restart=always
User=root
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
else
  echo "✔ systemd service already exists"
fi

# --------------------------------------
# Enable & start service
# --------------------------------------
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable redis-commander
systemctl restart redis-commander

sudo tee /etc/apache2/sites-available/800-redis-commander.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName redis.${PROJECT_DOMAIN}
    Redirect permanent / https://redis.${PROJECT_DOMAIN}/
</VirtualHost>
EOF

sudo tee /etc/apache2/sites-available/800-redis-commander-ssl.conf > /dev/null <<EOF
<VirtualHost *:443>
    ServerName redis.${PROJECT_DOMAIN}

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/orizon.dev.pem
    SSLCertificateKeyFile /etc/apache2/ssl/orizon.dev.key

    ProxyPreserveHost On
    ProxyPass        / http://127.0.0.1:8081/
    ProxyPassReverse / http://127.0.0.1:8081/

    <Location />
        Require ip 127.0.0.1 192.168.56.0/24
    </Location>
</VirtualHost>
EOF

sudo a2ensite 800-redis-commander
sudo a2ensite 800-redis-commander-ssl
sudo systemctl reload apache2

# --------------------------------------
# Marker file (feature flag)
# --------------------------------------
touch /var/www/stack/.redis-commander.installed

# --------------------------------------
# Info
# --------------------------------------
echo "✔ Redis Commander installed and running"
echo "→ Access: https://redis.${PROJECT_DOMAIN}"
