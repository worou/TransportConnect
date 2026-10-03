#!/usr/bin/env bash
# Installation ou mise à jour de TransConnect sur o2switch, à lancer SUR LE SERVEUR :
#   DB_PASSWORD='…' OTP_DEBUG=1 bash install.sh
# Prérequis dans ~ : transco_app.tar.gz (dossier api/ + deploy/) et backoffice-web.tar.gz (build Flutter).
# Le compte doit utiliser PHP 8.3 (selectorctl --interpreter=php --set-user-current=8.3).
set -euo pipefail
cd ~

# 1. PHP 8.3 en ligne de commande avec les extensions nécessaires (n'affecte pas le reste du compte)
mkdir -p ~/.php83-cli
cat > ~/.php83-cli/transco.ini <<'INI'
extension=pdo.so
extension=pdo_pgsql.so
extension=intl.so
extension=sodium.so
extension=mbstring.so
extension=zip.so
extension=fileinfo.so
extension=phar.so
extension=opcache.so
memory_limit=512M
INI
cat > ~/php83 <<'SH'
#!/bin/sh
# PHP 8.3 CLI pour TransConnect (les sous-processus, ex. scripts Composer, héritent de la configuration)
export PHP_INI_SCAN_DIR="/opt/alt/php83/link/conf:$HOME/.php83-cli"
exec /opt/alt/php83/usr/bin/php "$@"
SH
chmod +x ~/php83

# 2. Code de l'API hors de la racine web
rm -rf ~/transco_app.new && mkdir -p ~/transco_app.new
tar -xzf ~/transco_app.tar.gz -C ~/transco_app.new --strip-components=1
if [ -d ~/transco_app ]; then
  # Mise à jour : on conserve la configuration et les clés
  cp ~/transco_app/.env.local ~/transco_app.new/ 2>/dev/null || true
  cp -r ~/transco_app/config/jwt ~/transco_app.new/config/ 2>/dev/null || true
  rm -rf ~/transco_app.old && mv ~/transco_app ~/transco_app.old
fi
mv ~/transco_app.new ~/transco_app

# 3. Configuration de production (créée une seule fois ; secrets générés ici)
if [ ! -f ~/transco_app/.env.local ]; then
  : "${DB_PASSWORD:?Indiquez DB_PASSWORD pour la première installation}"
  cat > ~/transco_app/.env.local <<ENV
APP_ENV=prod
APP_DEBUG=0
APP_SECRET=$(openssl rand -hex 32)
DATABASE_URL="postgresql://rise9482_transco:${DB_PASSWORD}@127.0.0.1:5432/rise9482_transconnect?serverVersion=9.6&charset=utf8"
JWT_PASSPHRASE=$(openssl rand -hex 32)
CORS_ALLOW_ORIGIN='^https://transco\.teranga\.re$'
DEFAULT_URI=https://transco.teranga.re
OTP_DEBUG=${OTP_DEBUG:-0}
UPLOAD_DIR=$HOME/transco.teranga.re/uploads
UPLOAD_BASE_URL=https://transco.teranga.re/uploads
ENV
  chmod 600 ~/transco_app/.env.local
fi

# 4. Dépendances, clés JWT, caches, racine web
cd ~/transco_app
PHP=~/php83 bash deploy/o2switch/deploy.sh
