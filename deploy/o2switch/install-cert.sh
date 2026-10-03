#!/usr/bin/env bash
# Installe dans cPanel le certificat Let's Encrypt obtenu par acme.sh pour transco.teranga.re.
# Utilisé comme --reloadcmd d'acme.sh : relancé automatiquement à chaque renouvellement.
set -euo pipefail

DOMAIN=transco.teranga.re
DIR=~/.acme.sh/$DOMAIN
enc() { perl -MURI::Escape -0777 -ne 'print uri_escape($_)' "$1"; }

uapi SSL install_ssl domain="$DOMAIN" \
  cert="$(enc "$DIR/$DOMAIN.cer")" \
  key="$(enc "$DIR/$DOMAIN.key")" \
  cabundle="$(enc "$DIR/ca.cer")" | grep -E "status:|errors:" -A1
