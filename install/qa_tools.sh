#!/usr/bin/env bash
#
# qa_tools.sh — Install & wire QA tools inside a Laravel project (Vagrant box).
# Assumes PHP, Composer, Apache already installed and project at /var/www/project/src
#
set -euo pipefail
IFS=$'\n\t'

# ----------------------------
# Config
# ----------------------------
PROJECT_SRC_DIR="/var/www/project/back/"
ENV_FILE="$PROJECT_SRC_DIR/.env"

# Composer flags (faster, non-interactive)
COMPOSER_FLAGS=(--no-interaction --no-progress --ansi)

# ----------------------------
# Log helpers
# ----------------------------
info()  { printf "\033[1;34m[INFO]\033[0m %s\n"  "$*"; }
ok()    { printf "\033[1;32m[ OK ]\033[0m %s\n"  "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[ERR ]\033[0m %s\n"  "$*" >&2; }

# ----------------------------
# Preflight checks
# ----------------------------
command -v php      >/dev/null 2>&1 || { err "PHP not found in PATH"; exit 1; }
command -v composer >/dev/null 2>&1 || { err "Composer not found in PATH"; exit 1; }

if [[ ! -d "$PROJECT_SRC_DIR" ]]; then
  err "Project dir not found: $PROJECT_SRC_DIR"
  exit 1
fi

if [[ ! -f "$PROJECT_SRC_DIR/composer.json" ]]; then
  err "No composer.json in $PROJECT_SRC_DIR — install Laravel first."
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$PROJECT_SRC_DIR/.env.example" ]]; then
    warn "$ENV_FILE missing — copying from .env.example"
    cp "$PROJECT_SRC_DIR/.env.example" "$ENV_FILE"
  else
    err "$ENV_FILE not found and no .env.example to bootstrap."
    exit 1
  fi
fi

# Load .env into current shell (export all), then disable export
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
ok "Loaded environment from $ENV_FILE"

cd "$PROJECT_SRC_DIR"
sudo rm -rf vendor composer.lock
composer install

# Double-check artisan presence
if [[ ! -f "artisan" ]]; then
  err "artisan file missing in $PROJECT_SRC_DIR"
  exit 1
fi
ok "Detected Laravel project at $PROJECT_SRC_DIR"

info "Installing Laravel-compatible QA tools…"

# ----------------------------
# Pest (tests) + ensure no hard-pinned phpunit conflict
# ----------------------------
info "Installing Pest (tests)…"
composer remove --dev phpunit/phpunit "${COMPOSER_FLAGS[@]}" || true
composer require --dev pestphp/pest:^4.0 pestphp/pest-plugin-laravel:^4.0 "${COMPOSER_FLAGS[@]}" --with-all-dependencies
php artisan pest:install || true
ok "Pest ready"

# ----------------------------
# Pint (formatter)
# ----------------------------
info "Installing Pint (formatter)…"
composer require --dev laravel/pint "${COMPOSER_FLAGS[@]}"
# First run can fail if no code yet — make it best-effort
./vendor/bin/pint --preset=laravel || true
ok "Pint installed"

# ----------------------------
# Larastan (PHPStan for Laravel)
# ----------------------------
info "Installing Larastan (PHPStan)…"
composer require --dev larastan/larastan phpstan/phpstan "${COMPOSER_FLAGS[@]}"

if [[ ! -f phpstan.neon.dist ]]; then
  cat > phpstan.neon.dist <<'NEON'
includes:
  - vendor/larastan/larastan/extension.neon

parameters:
  paths:
    - app
    - database
  level: 7
  checkMissingIterableValueType: false
  ignoreErrors:
    - identifier: missingType.iterableValue
    - '#Unsafe usage of new static#'
NEON
  ok "Created phpstan.neon.dist"
else
  warn "phpstan.neon.dist already exists — not overwriting"
fi

# ----------------------------
# IDE Helper + Psalm (+ plugin Laravel)
# ----------------------------
info "Installing IDE Helper & Psalm…"
# ide-helper v3.x recommandé pour Laravel 12
composer require --dev barryvdh/laravel-ide-helper:3.5.5 "${COMPOSER_FLAGS[@]}"
php artisan ide-helper:generate || true

# Psalm 6+ et plugin 3.x (compatible Laravel 12)
composer require --dev vimeo/psalm:^6.0 psalm/plugin-laravel:^3.0 "${COMPOSER_FLAGS[@]}"
./vendor/bin/psalm-plugin enable psalm/plugin-laravel || true
# ./vendor/bin/psalm --init || true   # uncomment si tu veux un psalm.xml par défaut
ok "Psalm + plugin Laravel wired"

# ----------------------------
# PHPMD (code smells)
# ----------------------------
info "Installing PHPMD…"
composer require --dev phpmd/phpmd:@stable "${COMPOSER_FLAGS[@]}"

# Ruleset adapté Laravel
if [[ ! -f phpmd.ruleset.xml ]]; then
  cat > phpmd.ruleset.xml <<'XML'
<?xml version="1.0"?>
<ruleset name="Sane Laravel ruleset"
         xmlns="http://pmd.sf.net/ruleset/1.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="http://pmd.sf.net/ruleset_xml_schema.xsd">
    <description>
        Enable useful rules and allow common Laravel Facade static calls.
    </description>

    <rule ref="rulesets/cleancode.xml">
        <exclude name="StaticAccess" />
    </rule>

    <rule ref="rulesets/cleancode.xml/StaticAccess">
        <properties>
            <property name="exceptions">
                <value>
                    \Illuminate\Support\Facades\App,
                    \Illuminate\Support\Facades\Artisan,
                    \Illuminate\Support\Facades\Auth,
                    \Illuminate\Support\Facades\Blade,
                    \Illuminate\Support\Facades\Broadcast,
                    \Illuminate\Support\Facades\Bus,
                    \Illuminate\Support\Facades\Cache,
                    \Illuminate\Support\Facades\Config,
                    \Illuminate\Support\Facades\Cookie,
                    \Illuminate\Support\Facades\Crypt,
                    \Illuminate\Support\Facades\Date,
                    \Illuminate\Support\Facades\DB,
                    \Illuminate\Support\Facades\Event,
                    \Illuminate\Support\Facades\File,
                    \Illuminate\Support\Facades\Gate,
                    \Illuminate\Support\Facades\Hash,
                    \Illuminate\Support\Facades\Http,
                    \Illuminate\Support\Facades\Lang,
                    \Illuminate\Support\Facades\Log,
                    \Illuminate\Support\Facades\Mail,
                    \Illuminate\Support\Facades\Notification,
                    \Illuminate\Support\Facades\ParallelTesting,
                    \Illuminate\Support\Facades\Password,
                    \Illuminate\Support\Facades\Queue,
                    \Illuminate\Support\Facades\RateLimiter,
                    \Illuminate\Support\Facades\Redirect,
                    \Illuminate\Support\Facades\Redis,
                    \Illuminate\Support\Facades\Request,
                    \Illuminate\Support\Facades\Response,
                    \Illuminate\Support\Facades\Route,
                    \Illuminate\Support\Facades\Schema,
                    \Illuminate\Support\Facades\Session,
                    \Illuminate\Support\Facades\Storage,
                    \Illuminate\Support\Facades\URL,
                    \Illuminate\Support\Facades\Validator,
                    \Illuminate\Support\Facades\View
                </value>
            </property>
        </properties>
    </rule>

    <rule ref="rulesets/codesize.xml" />
    <rule ref="rulesets/controversial.xml" />
    <rule ref="rulesets/design.xml" />
    <rule ref="rulesets/naming.xml" />
    <rule ref="rulesets/unusedcode.xml" />
</ruleset>
XML
  ok "Created phpmd.ruleset.xml"
else
  warn "phpmd.ruleset.xml already exists — not overwriting"
fi

# ----------------------------
# Final Output
# ----------------------------
cat <<'MSG'

✅ QA toolchain installed.

Useful commands:
  • ./vendor/bin/pint                  # format code (Laravel preset)
  • ./vendor/bin/pest                  # run tests
  • ./vendor/bin/phpstan analyse       # static analysis (Larastan)
  • ./vendor/bin/phpmd app xml phpmd.ruleset.xml
  • php artisan ide-helper:generate    # IDE helpers
  • ./vendor/bin/psalm                 # Psalm analysis

Tips:
  - Add these to CI.
  - Tweak phpstan.neon.dist level, and rules in phpmd.ruleset.xml as your codebase matures.

Happy building! 🚀
MSG
