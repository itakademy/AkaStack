#!/usr/bin/env bash
#
# phpmyadmin.sh
# Installs phpMyAdmin on Debian/Ubuntu guests (Apache assumed).
# Requires: PHP, Apache, MySQL/MariaDB already installed & running.
#

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

# Basic sanity checks for expected vars (adapt if your names differ)
: "${MYSQL_ROOT_PASSWORD:?Missing MYSQL_ROOT_PASSWORD in $ENV_FILE}"

# -------- Remove phpMyAdmin if present (clean) --------
if is_pkg_installed phpmyadmin; then
  echo "🔍 phpMyAdmin detected — purging…"
  sudo DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y phpmyadmin >/dev/null
  sudo apt-get -y autoremove >/dev/null
  echo "✅ phpMyAdmin removed."
else
  echo "✅ phpMyAdmin not installed — nothing to remove."
fi

# -------- Install phpMyAdmin (non-interactive, robust) --------
sudo apt-get update -y -qq

# Prefer dbconfig-common config file over debconf-set-selections (more reliable)
# It lets package scripts configure DB user/db silently.
sudo install -d -m 0755 /etc/dbconfig-common
sudo tee /etc/dbconfig-common/phpmyadmin.conf > /dev/null <<EOF
dbc_install='true'
dbc_upgrade='true'
dbc_remove=''
dbc_dbtype='mysql'
dbc_dbuser='phpmyadmin'
dbc_dbpass='${MYSQL_ROOT_PASSWORD}'
dbc_dbserver='localhost'
dbc_dbport=''
dbc_dbname='phpmyadmin'
dbc_admin='root'
dbc_basepath=''
dbc_ssl=''
dbc_authmethod_admin=''
dbc_authmethod_user=''
EOF

# Non-interactive install (avoids any debconf prompts)
echo "🧪 Installing phpMyAdmin (non-interactive)…"
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install phpmyadmin >/dev/null 2>&1
# Mark phpMyAdmin as installed
touch /var/www/stack/.phpmyadmin.installed

# -------- Final output --------
cat <<MSG

✅ PhpMyAdmin installation complete.

Access:
  • URL:  https://${PROJECT_DOMAIN}/phpmyadmin
  • Login:
        Username: root
        Password: ${MYSQL_ROOT_PASSWORD}

Happy building! 🚀
MSG
