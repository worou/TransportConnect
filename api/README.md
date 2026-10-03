# TransConnect – API (Symfony 7.4 + API Platform 5)

API REST générée par API Platform à partir des entités Doctrine, avec documentation Swagger / OpenAPI.

- **Swagger UI** : http://127.0.0.1:8000/api
- **OpenAPI (JSON)** : http://127.0.0.1:8000/api/docs.jsonopenapi
- Formats : `application/json` (JSON simple) et `application/ld+json` (JSON-LD / Hydra, par défaut)
- PATCH : `Content-Type: application/merge-patch+json`
- Clés JSON en snake_case (`prix_propose`, `created_at`…), relations sous forme d'IRI (`/api/villes/1`)

## Démarrer

PostgreSQL 16, PHP 8.3 et Composer sont installés en version portable dans `../.tools`
(le PHP 8.0 de XAMPP est trop ancien). Depuis le dossier `export` :

```powershell
# 1. Base de données (port 5433)
.tools\pgsql\bin\pg_ctl -D .tools\pgdata -o "-p 5433" -l .tools\pg.log start

# 2. API
cd api
..\.tools\php\php.exe ..\.tools\composer.phar install      # première fois seulement
..\.tools\php\php.exe -S 127.0.0.1:8000 -t public dev-router.php
```

Arrêter la base : `.tools\pgsql\bin\pg_ctl -D .tools\pgdata stop`.
Remettre les données de démo : `.tools\pgsql\bin\psql -p 5433 -U postgres -d transconnect -f 01_schema.sql`, puis `-f 02_seed.sql`.

En développement, la **première requête** après un vidage du cache (`cache:clear`) peut prendre
jusqu'à une minute sous Windows, le temps que Symfony génère ses caches. Les suivantes répondent en ~1 s.

La connexion est dans `.env.local` :

```
DATABASE_URL="postgresql://postgres@127.0.0.1:5433/transconnect?serverVersion=16&charset=utf8"
```

## Authentification (OTP + JWT)

Toutes les routes `/api/*` exigent un JWT, sauf `/api/auth/*`, la documentation et Swagger UI.

1. `POST /api/auth/send-otp` `{"telephone": "+22997123456"}` → `otp_id`
   (code à 6 chiffres envoyé par SMS ; avec `OTP_DEBUG=1` il est renvoyé dans `code_dev`).
2. `POST /api/auth/verify-otp` `{"otp_id": "…", "code": "123456", "nom_complet": "…"}` →
   `access_token` (JWT, 1 h), `refresh_token` (30 jours), `user_id`, `role`.
   Numéro inconnu : un **compte marchand** est créé (`nouveau_compte: true`).
3. Appeler l'API avec `Authorization: Bearer <access_token>`.
   Dans Swagger UI : bouton **Authorize**, coller le `access_token`.
4. `POST /api/auth/refresh` `{"refresh_token": "…"}` → nouveaux jetons (l'ancien refresh token est révoqué).
5. `POST /api/auth/logout` `{"refresh_token": "…"}` → révocation.
6. `GET /api/me` → profil de l'utilisateur connecté.

Protections : code valable 5 min, 3 essais par code (puis 429), 3 envois par numéro sur 15 min,
codes et refresh tokens stockés hachés, comptes suspendus refusés.

Comptes de démo (données `02_seed.sql`) — se connecter avec le numéro + le `code_dev` :

| Rôle | Nom | Téléphone |
|---|---|---|
| admin | Admin TransConnect | +22990000001 |
| marchand | Ali Dossou | +22997123456 |
| marchand | Fatou Bello | +22996112233 |
| représentant | Jean Kpadonou | +22996000001 |
| chauffeur | Moussa Sanni | +22995000002 |

### Droits par rôle

| Ressource | Règle |
|---|---|
| Villes, transporteurs, véhicules, grilles | Lecture : tous ; écriture : admin |
| Utilisateurs | Liste et création : admin ; chacun lit et modifie son profil. `role`, `telephone`, `statut_compte`, `transporteur`, `zones_intervention` : admin seulement (sinon ignorés) |
| Demandes | Un marchand ne voit et ne crée que **ses** demandes ; représentants et chauffeurs peuvent les consulter |
| Évaluations | Créées par un représentant pour lui-même ; modifiées par ce représentant |
| Devis | Créé par le représentant de l'évaluation ; le marchand peut changer le statut, pas le prix |
| Paiements | Initiés par le marchand de la demande ; `statut` (réussi/échoué) et séquestre : **admin / webhook PSP uniquement** |
| Livraisons | Créées par un représentant ; mises à jour par le chauffeur assigné ou un représentant |
| Litiges | Ouverts par une partie pour son compte ; arbitrés par un admin |
| Notifications, KYC | Chacun ne voit que les siens ; validation KYC par un admin |

Clés JWT : `config/jwt/` (générées avec `lexik:jwt:generate-keypair` ; sous Windows, définir
`OPENSSL_CONF=..\.tools\php\extras\ssl\openssl.cnf` avant). **Ne pas versionner** `.env.local` ni `config/jwt/*.pem`.

## La base reste maîtresse du schéma

Le schéma est défini par `../01_schema.sql` (types ENUM, triggers, vues). Les entités Doctrine
s'y **adaptent** :

- **Ne jamais lancer** `doctrine:schema:update`, `make:migration` ni `doctrine:migrations:diff`.
- Pour vérifier le mapping : `php bin/console doctrine:schema:validate --skip-sync`.
- Toute évolution passe d'abord par le SQL, puis par l'entité correspondante.
- Les colonnes remplies par la base (`numero`, `created_at`, `montant_commission`…) sont en lecture seule,
  et l'entité est relue après chaque écriture pour refléter les triggers.

## Ressources

| Ressource | Opérations | Filtres (`GET` collection) |
|---|---|---|
| `/api/villes` | CRUD | `est_couverte` |
| `/api/transporteurs` | lecture, création, PATCH | `statut` |
| `/api/utilisateurs` | lecture, création, PATCH | `role`, `statut_compte`, `transporteur` |
| `/api/document_kycs` | lecture, création, PATCH | `utilisateur`, `statut_verification` |
| `/api/vehicules` | CRUD | `transporteur`, `actif` |
| `/api/grille_tarifaires` | lecture, création, PATCH | `transporteur`, `actif` |
| `/api/demandes` | lecture, création, PATCH | `marchand`, `statut`, `numero`, `ville_depart` |
| `/api/historique_statuts` | lecture seule | `demande` |
| `/api/evaluations` | lecture, création, PATCH | `demande`, `representant` |
| `/api/devis` | lecture, création, PATCH | `evaluation`, `statut` |
| `/api/message_negociations` | lecture, création | `devis` |
| `/api/paiements` | lecture, création, PATCH | `devis`, `statut` |
| `/api/livraisons` | lecture, création, PATCH | `demande`, `chauffeur`, `statut` |
| `/api/position_gps` | lecture, création | `livraison` |
| `/api/incidents` | lecture, création, PATCH | `livraison` |
| `/api/photos` | lecture, création, suppression | `demande`, `evaluation`, `livraison` |
| `/api/litiges` | lecture, création, PATCH | `statut`, `demande` |
| `/api/avis` | lecture, création | `livraison` |

`otp_code`, `refresh_token` et `audit_log` ne sont pas exposés (usage interne).

## Règles appliquées automatiquement

| Action | Effet |
|---|---|
| `POST /api/demandes` | Numéro `TC-AAAA-NNNNN`, statut `EN_ATTENTE` |
| `POST /api/evaluations` | Demande → `REPRESENTANT_ASSIGNE` |
| `PATCH` évaluation avec `date_checkin` | Demande → `EN_EVALUATION` (check-in ≤ 100 m) |
| `PATCH` évaluation avec `date_soumission` | Refusé s'il y a moins de 2 photos |
| `POST /api/devis` | `prix_suggere` calculé par la grille, `prix_propose` = suggéré par défaut, demande → `PRIX_PROPOSE` |
| `PATCH` devis | `prix_propose` limité à ±20 % du suggéré, avec justification |
| `POST /api/message_negociations` | 3 messages maximum par partie |
| `POST`/`PATCH` paiement `statut: reussi` | Séquestre `bloque`, devis `accepte`, demande → `PAYE`, commission calculée |
| `POST /api/livraisons` | `code_reception` (4 chiffres) obligatoire, stocké haché, jamais renvoyé |
| `PATCH` livraison `statut` | `enleve`/`en_transit`/`arrive` → demande `EN_TRANSIT` ; `livre` exige `code_reception` → demande `LIVRE` |
| `POST /api/avis` | Recalcul des notes moyennes |
| `POST /api/litiges` | Demande → `LITIGE` |

Les règles refusées par la base renvoient **422** (ou **409** pour un doublon) avec le message métier.

## Exemple

```bash
curl -X POST http://127.0.0.1:8000/api/demandes \
  -H "Content-Type: application/json" -H "Accept: application/json" \
  -d '{"marchand": "/api/utilisateurs/40000000-0000-0000-0000-000000000002",
       "ville_depart": "/api/villes/1", "ville_arrivee": "/api/villes/4",
       "adresse_depart": "Akpakpa, rue 12", "adresse_arrivee": "Centre-ville",
       "type_marchandise": "standard", "description": "20 sacs de riz",
       "poids_estime": "1000", "date_enlevement": "2026-10-10", "distance_km": "410"}'
```

## À faire

- Brancher un fournisseur SMS dans `src/Service/SmsSender.php` (Africa's Talking, Twilio…), puis `OTP_DEBUG=0`.
- Intégration PSP (CinetPay, Wave…) : webhook qui passe le paiement à `reussi`.
- Envoi du code de réception par SMS au marchand.
