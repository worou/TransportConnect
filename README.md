# TransConnect

Plateforme de mise en relation **marchands ↔ transporteurs** : un marchand demande un transport,
un représentant du transporteur évalue la marchandise sur place et propose un prix, le marchand paie
(fonds en séquestre), la livraison est confirmée par code OTP.

| Dossier | Contenu |
|---|---|
| [`01_schema.sql`](01_schema.sql), [`02_seed.sql`](02_seed.sql) | Base PostgreSQL (schéma `transconnect` : tables, types, triggers, vues) et données de démo |
| [`api/`](api/README.md) | API REST Symfony 7.4 + API Platform 5, documentation Swagger, authentification OTP + JWT |
| [`backoffice/`](backoffice/README.md) | Back-office d'administration en Flutter Web |
| [`mobile/`](mobile/README.md) | Application mobile Flutter (Android) : espaces marchand et représentant |
| [`deploy/o2switch/`](deploy/o2switch/README.md) | Déploiement en production sur https://transco.teranga.re |
| `docker-compose.yml` | PostgreSQL 16 avec chargement automatique des scripts |

## Base de données

### Avec Docker
```bash
docker compose up -d
docker exec -it transconnect-db psql -U transconnect -d transconnect
```
Les scripts sont exécutés automatiquement au premier démarrage (volume vide).
Pour repartir de zéro : `docker compose down -v && docker compose up -d`.

### Sans Docker
```bash
createdb transconnect
psql -d transconnect -f 01_schema.sql
psql -d transconnect -f 02_seed.sql   # facultatif : données de démo
```

### Exemples de requêtes
```sql
SET search_path TO transconnect;
SELECT * FROM v_suivi_demande;                       -- suivi des demandes
SELECT * FROM v_missions_disponibles
 WHERE id_representant = '40000000-0000-0000-0000-000000000005';
SELECT * FROM v_kpi_admin;                           -- tableau de bord admin
SELECT * FROM historique_statut ORDER BY id_historique;
SELECT calculer_prix_suggere('30000000-0000-0000-0000-000000000001', 410, 1050, 'standard', 'express');  -- 45000
```

## Démarrage rapide (développement)

Prérequis : PostgreSQL 16, PHP 8.2+ (extensions `pdo_pgsql`, `intl`, `openssl`, `sodium`), Composer, Flutter 3.x.

```bash
# 1. Base (voir ci-dessus), puis l'API
cd api
composer install
cp .env .env.local      # renseigner DATABASE_URL, APP_SECRET, JWT_PASSPHRASE, OTP_DEBUG=1
php bin/console lexik:jwt:generate-keypair
php -S 127.0.0.1:8000 -t public dev-router.php     # Swagger : http://127.0.0.1:8000/api

# 2. Back-office
cd ../backoffice
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_URL=http://127.0.0.1:8000
```

Compte administrateur de démo : `+22990000001` (le code OTP est renvoyé par l'API quand `OTP_DEBUG=1`).
