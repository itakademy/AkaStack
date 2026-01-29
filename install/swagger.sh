#!/usr/bin/env bash

set -e

echo "======================================"
echo " Installing Swagger UI"
echo "======================================"

# -------- Config / Inputs --------
PROJECT_SRC_DIR="/var/www/stack"
ENV_FILE="$PROJECT_SRC_DIR/project.env"

# -------- Helpers --------
is_pkg_installed() {
  # returns 0 if installed, non-zero otherwise
  dpkg-query -Wf'${db:Status-abbrev}' "$1" 2>/dev/null | grep -q '^i'
}

# -------- Load .env --------
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
  echo "✅ Loaded environment variables from $ENV_FILE"
else
  echo "❌ $ENV_FILE not found. Create it from ../.env.example."
  exit 1
fi

SWAGGER_DIR="/var/www/stack/swagger"
MARKER_FILE="/var/www/stack/.swagger.installed"
APACHE_CONF="/etc/apache2/conf-available/swagger.conf"


# --------------------------------------
# Create directory
# --------------------------------------
mkdir -p "$SWAGGER_DIR"
cd "$SWAGGER_DIR"

# --------------------------------------
# Download Swagger UI
# --------------------------------------
if [ ! -f "$SWAGGER_DIR/index.html" ]; then
  echo "▶ Downloading Swagger UI"
  curl -sL https://github.com/swagger-api/swagger-ui/archive/refs/heads/master.tar.gz \
    | tar xz --strip-components=2 swagger-ui-master/dist
else
  echo "✔ Swagger UI already installed"
fi

# --------------------------------------
# Configure Swagger UI
# --------------------------------------
echo "▶ Configuring Swagger UI"

cat <<EOF > "$SWAGGER_DIR/swagger-config.js"
window.onload = function () {
  window.ui = SwaggerUIBundle({
    url: "/api/docs.json",
    dom_id: "#swagger-ui",
    presets: [
      SwaggerUIBundle.presets.apis,
      SwaggerUIStandalonePreset
    ],
    layout: "StandaloneLayout"
  });
};
EOF

# Patch index.html to load custom config
sed -i 's|SwaggerUIBundle({|SwaggerUIBundle({|g' index.html
sed -i 's|url:.*|url: "/api/docs.json",|g' index.html

# --------------------------------------
# Apache configuration
# --------------------------------------
echo "▶ Configuring Apache"

sudo tee /etc/apache2/sites-available/700-swagger.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName swagger.${PROJECT_DOMAIN}
    Redirect permanent / https://swagger.${PROJECT_DOMAIN}/
</VirtualHost>
EOF

sudo tee /etc/apache2/sites-available/700-swagger-ssl.conf > /dev/null <<EOF
<VirtualHost *:443>
    ServerName swagger.${PROJECT_DOMAIN}
    DocumentRoot $SWAGGER_DIR
    <Directory $SWAGGER_DIR>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/orizon.dev.pem
    SSLCertificateKeyFile /etc/apache2/ssl/orizon.dev.key

    <Location />
        Require ip 127.0.0.1 192.168.56.0/24
    </Location>
</VirtualHost>
EOF

sudo a2ensite 700-swagger
sudo a2ensite 700-swagger-ssl
sudo systemctl reload apache2


# --------------------------------------
# Marker file
# --------------------------------------
touch "$MARKER_FILE"

# --------------------------------------
# Info
# --------------------------------------
echo "✔ Swagger UI installed"
echo "→ Access: https://swagger.${PROJECT_DOMAIN}"
