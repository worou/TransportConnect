#!/usr/bin/env bash
# Déploiement / mise à jour de TransConnect sur o2switch, à lancer SUR LE SERVEUR (ssh).
#   Projet Symfony : ~/transco_app        (hors racine web)
#   Racine web     : ~/transco.teranga.re (back-office Flutter + index.php de l'API)
# Prérequis : ~/transco_app/.env.local rempli (voir README), archive du back-office dans ~/backoffice-web.tar.gz
set -euo pipefail

APP=~/transco_app
WEB=~/transco.teranga.re
PHP=${PHP:-php}

cd "$APP"
$PHP "$(command -v composer)" install --no-dev --optimize-autoloader --no-interaction --no-progress
[ -f config/jwt/private.pem ] || $PHP bin/console lexik:jwt:generate-keypair --no-interaction
$PHP bin/console cache:clear
$PHP bin/console assets:install public --no-interaction

# Racine web : back-office + contrôleur frontal + ressources de Swagger UI
if [ -f ~/backoffice-web.tar.gz ]; then
  find "$WEB" -mindepth 1 -maxdepth 1 ! -name cgi-bin ! -name .well-known -exec rm -rf {} +
  tar -xzf ~/backoffice-web.tar.gz -C "$WEB"
fi
cp deploy/o2switch/index.php deploy/o2switch/.htaccess "$WEB"/
rm -rf "$WEB/bundles" && cp -r public/bundles "$WEB/bundles"

# Lisible par le serveur web (sinon 403 « unable to read htaccess »)
find "$WEB" -path "$WEB/cgi-bin" -prune -o -type d -exec chmod 755 {} + -o -type f -exec chmod 644 {} +

echo "Déployé : https://transco.teranga.re (Swagger : https://transco.teranga.re/api)"
