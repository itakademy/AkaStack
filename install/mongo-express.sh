#!/usr/bin/env bash
set -e

echo "======================================"
echo " Installing Mongo Express"
echo "======================================"

MARKER_FILE="/var/www/stack/.mongo-express.installed"
SERVICE_FILE="/etc/systemd/system/mongo-express.service"
APP_DIR="/opt/mongo-express"

# --------------------------------------
# Prerequisites
# --------------------------------------
if ! command -v node >/dev/null 2>&1; then
  echo "❌ Node.js is required"
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "❌ npm is required"
  exit 1
fi

if ! command -v mongod >/dev/null 2>&1; then
  echo "❌ MongoDB must be installed first"
  exit 1
fi

# shellcheck disable=SC1090
set -a
source /var/www/stack/project.env
set +a

# --------------------------------------
# Install Mongo Express
# --------------------------------------

echo "▶ Installing Mongo Express"
sudo rm -rf /opt/mongo-express
sudo git clone https://github.com/mongo-express/mongo-express.git /opt/mongo-express
cd /opt/mongo-express
sudo npm install

sudo sed -i 's/8081/8082/g' /opt/mongo-express/config.default.js
sudo sed -i "/site:[[:space:]]*{/a\ \ \ \ sessionSecret: \"oriz0nStackSuperSecret\"," /opt/mongo-express/config.default.js

# --------------------------------------
# Configuration
# --------------------------------------
echo "▶ Configuring Mongo Express"

sudo tee /opt/mongo-express/config.cjs  <<EOF
module.exports = {
  mongodb: {
    server: '127.0.0.1',
    port: 27017,
    enableAdmin: true
  },
  site: {
    baseUrl: '/',
    port: 8082,
    sessionSecret: "oriz0nStackSuperSecret"
  },
  useBasicAuth: false,
  options: {
    readOnly: false
  }
};
EOF

sudo tee /opt/mongo-express/config.js  <<EOF
import cfg from './config.cjs';
export default cfg;
EOF

# --------------------------------------
# systemd service
# --------------------------------------
echo "▶ Creating systemd service"

sudo tee $SERVICE_FILE  <<EOF
[Unit]
Description=Mongo Express
After=network.target mongod.service

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node /opt/mongo-express/app.js
Restart=always
Environment=NODE_ENV=production
Environment=ME_CONFIG_MONGODB_URL=mongodb://127.0.0.1:27017
Environment=ME_CONFIG_CONFIGFILE=/opt/mongo-express/config.cjs
Environment=ME_CONFIG_SITE_PORT=8082

[Install]
WantedBy=multi-user.target
EOF

# --------------------------------------
# Enable & start
# --------------------------------------
sudo systemctl daemon-reload
sudo systemctl enable mongo-express
sudo systemctl restart mongo-express

sudo tee /etc/apache2/sites-available/600-mongo-express.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName mongo.${PROJECT_DOMAIN}
    Redirect permanent / https://mongo.${PROJECT_DOMAIN}/
</VirtualHost>
EOF

sudo tee /etc/apache2/sites-available/600-mongo-express-ssl.conf > /dev/null <<EOF
<VirtualHost *:443>
    ServerName mongo.${PROJECT_DOMAIN}

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/orizon.dev.pem
    SSLCertificateKeyFile /etc/apache2/ssl/orizon.dev.key

    ProxyPreserveHost On
    ProxyPass        / http://127.0.0.1:8082/
    ProxyPassReverse / http://127.0.0.1:8082/

    <Location />
        Require ip 127.0.0.1 192.168.56.0/24
    </Location>
</VirtualHost>
EOF

sudo a2ensite 600-mongo-express
sudo a2ensite 600-mongo-express-ssl
sudo systemctl reload apache2
# --------------------------------------
# Marker file
# --------------------------------------
touch "$MARKER_FILE"

echo "✔ Mongo Express installed and running"
echo "→ Internal URL: https://mongo.${PROJECT_DOMAIN}"
