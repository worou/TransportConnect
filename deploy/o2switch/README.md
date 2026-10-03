# Déploiement sur o2switch – https://transco.teranga.re

| Élément | Emplacement sur le serveur |
|---|---|
| Back-office Flutter (racine du site) | `~/transco.teranga.re/` |
| API Symfony (hors racine web) | `~/transco_app/` – contrôleur frontal : `~/transco.teranga.re/index.php` |
| Configuration de production (secrets) | `~/transco_app/.env.local` (droits 600, jamais versionné) |
| Clés JWT | `~/transco_app/config/jwt/` |
| Base | PostgreSQL 9.6, base `rise9482_transconnect`, utilisateur `rise9482_transco` |
| PHP | 8.3 pour le compte (`selectorctl --interpreter=php --set-user-current=8.3`) ; CLI : `~/php83` |

Le `.htaccess` sert le back-office à la racine, envoie `/api` vers Symfony, force le HTTPS,
transmet l'en-tête `Authorization` et bloque les fichiers `.env`.

## Prérequis

- **Accès SSH** : l'IP du poste doit être autorisée dans cPanel › *Autorisation SSH* (port 22).
- **Certificat HTTPS** : cPanel › *Let's Encrypt* pour `transco.teranga.re`.

## Mettre à jour

Depuis le poste de développement (dossier du dépôt) :

```bash
# 1. Construire le back-office pour la production
cd backoffice && flutter build web --release --dart-define=API_URL=https://transco.teranga.re --output build/web-prod && cd ..

# 2. Archives (sans vendor, var, .env.local ni clés)
mkdir -p /tmp/pkg/transco_app/deploy
tar -C api --exclude=./vendor --exclude=./var --exclude=./.env.local --exclude=./config/jwt -cf - . | tar -C /tmp/pkg/transco_app -xf -
cp -r deploy/o2switch /tmp/pkg/transco_app/deploy/
tar -C /tmp/pkg -czf /tmp/transco_app.tar.gz transco_app
tar -C backoffice/build/web-prod -czf /tmp/backoffice-web.tar.gz .

# 3. Envoi et installation (la configuration et les clés existantes sont conservées)
scp /tmp/transco_app.tar.gz /tmp/backoffice-web.tar.gz deploy/o2switch/install.sh rise9482@cassis.o2switch.net:
ssh rise9482@cassis.o2switch.net 'bash install.sh && rm install.sh *.tar.gz'
```

Première installation uniquement : `DB_PASSWORD='…' OTP_DEBUG=1 bash install.sh` crée `.env.local`
(secrets `APP_SECRET` et `JWT_PASSPHRASE` générés sur le serveur).

## Base de données

Le schéma est compatible PostgreSQL 9.6 (version fournie par o2switch) et 16.

```bash
ssh rise9482@cassis.o2switch.net
PGPASSWORD='…' psql -h 127.0.0.1 -U rise9482_transco -d rise9482_transconnect -f 01_schema.sql
```

⚠️ `01_schema.sql` **supprime et recrée** le schéma : ne pas le relancer sur des données réelles.

## Codes OTP

Tant qu'aucun fournisseur SMS n'est branché (`api/src/Service/SmsSender.php`), `OTP_DEBUG=1` renvoie
le code dans la réponse : pratique pour tester, mais **n'importe qui peut alors se connecter**.
Passer `OTP_DEBUG=0` dans `~/transco_app/.env.local` puis `~/php83 ~/transco_app/bin/console cache:clear`
dès que les SMS fonctionnent.
