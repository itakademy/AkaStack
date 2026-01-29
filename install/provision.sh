#!/bin/bash
# Provisioning script – Ubuntu 24.04 LTS

PROJECT_VERSION=$(cat /var/www/stack/VERSION)

export DEBIAN_FRONTEND=noninteractive
echo ""
echo ""
echo "   ___   "
echo "  (o,o)  "
echo " <  .  >  It-Akademy "
echo "  -----  "
echo ""
echo -e "https://www.it-akademy.fr"
echo ""
echo -e "VM for project $PROJECT_NAME v.$PROJECT_VERSION "
echo ""
echo "+-------------------------------+"
echo "PROVISIONING"
echo ""

# workaround to prevent post-install problems with openssh-server
# temporary fix for openssh-server post-install script issues
echo "🔧 Handling openssh-server post-install script issues..."
if grep -q "half-configured" /var/lib/dpkg/status || ps aux | grep -q "[o]penssh-server.*postinst"; then
  sudo mv /var/lib/dpkg/info/openssh-server.postinst /tmp/openssh-server.postinst.bak &> /dev/null 2>&1 || true
  sudo dpkg --configure -a &> /dev/null 2>&1 || true
fi
sudo apt-get purge -qq -y openssh-server openssh-client &> /dev/null 2>&1 || true
sudo apt-get update -qq &> /dev/null 2>&1
sudo apt-get install -qq -y openssh-server openssh-client &> /dev/null 2>&1 || true
echo -e "✅ Workaround to prevent post-install problems with openssh-server applied."
if sudo systemctl is-active ssh &> /dev/null 2>&1; then
  echo -e "✅ Openssh-server has been installed and started successfully.\n"
else
  echo -e "⚠️ SSH service appears inactive, trying to restart...\n"
  sudo systemctl restart ssh /dev/null 2>&1 || true
fi

echo -e "📦 Updating the system..."
sudo apt-get update -qq &> /dev/null 2>&1
sudo apt-get upgrade -y -qq &> /dev/null 2>&1
echo -e "✅ System updated successfully.\n"

echo "📦 Installing system utilities..."
sudo apt-get install -y --no-install-recommends build-essential libssl-dev git curl wget zip unzip git-core ca-certificates apt-transport-https locate software-properties-common dirmngr &> /dev/null 2>&1
echo -e "✅ System utilities installed successfully.\n"

echo "📦 Installing Apache 2 web server..."
sudo apt-get install -y apache2 &> /dev/null 2>&1
echo -e "✅ Apache installed successfully.\n"
echo "🔧 Enabling required Apache modules..."
sudo a2enmod rewrite headers expires &> /dev/null 2>&1
echo -e "✅ Apache modules enabled successfully.\n"

echo "ServerName ${PROJECT_DOMAIN}" > /etc/apache2/conf-available/servername.conf
sudo a2enconf servername

sudo mkdir -p /etc/apache2/ssl
sudo cp /var/www/stack/certs/orizon.dev.key /etc/apache2/ssl/orizon.dev.key
sudo cp /var/www/stack/certs/orizon.dev.pem /etc/apache2/ssl/orizon.dev.pem
sudo chmod 600 /etc/apache2/ssl/orizon.dev.key
sudo chmod 644 /etc/apache2/ssl/orizon.dev.pem

a2dissite 000-default

sudo tee /etc/apache2/sites-available/999-default.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName ${PROJECT_DOMAIN}
    Redirect permanent / https://${PROJECT_DOMAIN}/
</VirtualHost>
EOF

sudo tee /etc/apache2/sites-available/999-default-ssl.conf > /dev/null <<EOF
<VirtualHost *:443>
    ServerName ${PROJECT_DOMAIN}
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.4-fpm.sock|fcgi://localhost"
    </FilesMatch>

    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/orizon.dev.pem
    SSLCertificateKeyFile /etc/apache2/ssl/orizon.dev.key

    ErrorLog /var/www/stack/logs/default_ssl_error.log
    CustomLog /var/www/stack/logs/default_ssl_access.log combined
</VirtualHost>
EOF

a2ensite 999-default
a2ensite 999-default-ssl

sudo rm -rf /etc/apache2/sites-available/000-default.conf
sudo rm -rf /etc/apache2/sites-available/default-ssl.conf

sudo mkdir -p /var/www/stack/logs &> /dev/null 2>&1
sudo rm -rf /var/www/html
sudo ln -s /var/www/stack/install/extras /var/www/html

echo "🔁 Restarting Apache service..."
sudo a2enmod ssl proxy proxy_fcgi proxy_http
sudo systemctl restart apache2 &> /dev/null 2>&1
echo -e "✅ Apache restarted successfully.\n"

echo "📦 Installing MariaDB..."
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get install -y mariadb-server &> /dev/null 2>&1
echo -e "✅ MariaDB installed successfully.\n"
sudo mysql <<EOF
ALTER USER 'root'@'localhost'
IDENTIFIED VIA mysql_native_password
USING PASSWORD('$MYSQL_ROOT_PASSWORD');
FLUSH PRIVILEGES;
EOF
echo -e "🔑 MariaDb root password is : $MYSQL_ROOT_PASSWORD\n"

echo "📦 Installing Redis..."
sudo apt-get install -y --no-install-recommends redis-server &> /dev/null 2>&1
sudo sed -ri 's/supervised no/supervised systemd/g' /etc/redis/redis.conf &> /dev/null 2>&1
sudo systemctl enable redis-server.service  &> /dev/null 2>&1
echo -e "✅ Redis installed and configured successfully.\n"

echo "📦 Installing PHP 8.4 (FPM mode)..."
sudo add-apt-repository ppa:ondrej/php -y &> /dev/null 2>&1
sudo apt-get update -qq &> /dev/null 2>&1
sudo apt-get upgrade -y -qq &> /dev/null 2>&1
sudo apt-get install -y --no-install-recommends \
  php8.4-fpm \
  php8.4-cli \
  php8.4-dev \
  php8.4-common \
  php8.4-mysql \
  php8.4-sqlite3 \
  php8.4-mbstring \
  php8.4-intl \
  php8.4-gd \
  php8.4-dom \
  php8.4-opcache \
  php8.4-ssh2 \
  php8.4-rrd \
  php8.4-yaml \
  php8.4-apcu \
  php8.4-memcached \
  php8.4-curl \
  php8.4-zip \
  php8.4-xml \
  php8.4-phpdbg \
  php-redis \
  &> /dev/null
sudo a2dismod php8.4 &> /dev/null || true
sudo a2dismod php8.3 &> /dev/null || true
sudo a2enconf php8.4-fpm &> /dev/null
sudo update-alternatives --set php /usr/bin/php8.4
sudo update-alternatives --set phar /usr/bin/phar8.4
sudo update-alternatives --set phar.phar /usr/bin/phar.phar8.4
sudo systemctl restart php8.4-fpm &> /dev/null 2>&1
sudo systemctl restart apache2 &> /dev/null 2>&1
sudo tee /var/www/html/phpinfo.php > /dev/null <<'EOF'
<?php
phpinfo();
EOF
sudo chmod 644 /var/www/html/phpinfo.php
sudo tee /etc/apache2/conf-available/phpinfo.conf > /dev/null <<'EOF'
Alias /phpinfo /var/www/html/phpinfo.php

<Directory /var/www>
    Require all granted
</Directory>

<FilesMatch phpinfo\.php$>
    SetHandler "proxy:unix:/run/php/php8.4-fpm.sock|fcgi://localhost"
</FilesMatch>
EOF
sudo a2enconf phpinfo &> /dev/null 2>&1
sudo systemctl restart apache2 &> /dev/null 2>&1
echo -e "✅ PHP 8.4 FPM installed and configured successfully.\n"


echo "📦 Installing MongoDb..."
curl -fsSL https://pgp.mongodb.com/server-${MONGODB_VERSION}.asc \
  | gpg --dearmor -o /usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg
echo "deb [signed-by=/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg] \
https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/${MONGODB_VERSION} multiverse" \
| tee /etc/apt/sources.list.d/mongodb-org-${MONGODB_VERSION}.list
apt-get update -y &> /dev/null 2>&1
apt-get install -y mongodb-org &> /dev/null 2>&1
sed -i 's/^  bindIp:.*$/  bindIp: 127.0.0.1/' /etc/mongod.conf
systemctl daemon-reexec
systemctl enable mongod
systemctl restart mongod

# Installer Node.js et npm
echo "📦 Installing Node.js..."
curl -sL https://deb.nodesource.com/setup_20.x | sudo -E bash - &> /dev/null 2>&1
sudo apt-get install -y --no-install-recommends nodejs &> /dev/null 2>&1
sudo npm install --global npm@latest  &> /dev/null 2>&1
sudo npm install --global yarn  &> /dev/null 2>&1
sudo npm install --global gulp-cli  &> /dev/null 2>&1
sudo npm install --global bower &> /dev/null 2>&1
echo -e "✅ Node.js, npm, yarn, gulp-cli, and bower installed successfully.\n"

echo "📦 Installing Composer..."
sudo php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" &> /dev/null 2>&1
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer  &> /dev/null 2>&1
sudo php -r "unlink('composer-setup.php');" &> /dev/null 2>&1
echo -e "✅ Composer installed successfully.\n"
sudo chmod a+w /var/www/html
cd /var/www/html
composer init \
    --name="project/docs" \
    --description="Project documentation renderer" \
    --type="project" \
    --no-interaction
sudo chmod a+w composer.json
composer require fastvolt/markdown --no-interaction &> /dev/null 2>&1

echo "🔧 Configuring development environment (access rights, inotify, cron jobs)..."
sudo chgrp -R www-data /var/www/stack&> /dev/null 2>&1
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf &> /dev/null 2>&1
sudo sysctl -p &> /dev/null 2>&1
composer global require deployer/deployer &> /dev/null 2>&1
echo "export PATH=\"$HOME/.composer/vendor/bin:$PATH\"" >> ~/.bashrc
source /home/vagrant/.bashrc
echo -e "✅ Development environment configured successfully.\n"

#removing previous install markers (if any)
rm -f /var/www/stack/*.installed

echo "▶ Ensuring SSH key for user vagrant"

VAGRANT_HOME="/home/vagrant"
SSH_DIR="$VAGRANT_HOME/.ssh"
KEY="$SSH_DIR/id_ed25519"

if [ ! -f "$KEY" ]; then
  echo "Generating SSH key for vagrant"

  sudo -u vagrant mkdir -p "$SSH_DIR"
  sudo -u vagrant chmod 700 "$SSH_DIR"

  sudo -u vagrant ssh-keygen -t ed25519 -C "vagrant@akastack" -f "$KEY" -N ""

  sudo chown -R vagrant:vagrant "$SSH_DIR"

  echo "--------------------------------------"
  echo " SSH key generated for vagrant"
  echo " Add this key to GitHub:"
  sudo -u vagrant cat "$KEY.pub"
  echo "--------------------------------------"
else
  echo "✔ SSH key already exists for vagrant"
fi
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_rsa

echo "▶ Installing GitHub CLI (gh)"

if ! command -v gh >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y curl ca-certificates gnupg

  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null

  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

  sudo apt update
  sudo apt install -y gh

  echo "✔ GitHub CLI installed"
else
  echo "✔ GitHub CLI already installed"
fi

sudo updatedb &> /dev/null 2>&1

echo "✅ Provisioning completed successfully!"
echo -e "📖 Please read README.md for more information\n"
echo -e "✅  All set! Please open your browser and navigate to:\n   http://$VM_IP"
echo -e "\n\n🚀 Happy coding!\n\n"
echo "+--------------------------------------------"
