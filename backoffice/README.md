# TransConnect – Back-office (Flutter Web)

Back-office d'administration conforme à la maquette **A01 – Admin dashboard** du canevas
« TransConnect – Maquettes » : barre latérale bleue (compteurs à traiter, commission, villes couvertes),
4 indicateurs avec évolution, période 7 j / 30 j / 12 mois, export CSV, demandes par jour,
zones actives, demandes récentes ; charte TransConnect (bleu `#1E4E8C`, orange `#F39C12`, Poppins / Inter).
Les autres écrans reprennent les mêmes composants (tableaux, badges de statut, fiches).

## Démarrer

L'API doit tourner (voir `../api/README.md`). Depuis le dossier `backoffice` :

```powershell
..\.tools\flutter\bin\flutter pub get
..\.tools\flutter\bin\flutter run -d chrome --web-port 8080
# ou une autre API :
..\.tools\flutter\bin\flutter run -d chrome --web-port 8080 --dart-define=API_URL=https://api.transconnect.app
```

Sans recompiler, servir la version déjà construite (`build/web`) :

```powershell
python -m http.server 8080 --bind 127.0.0.1 --directory build\web
```

Puis ouvrir http://127.0.0.1:8080.

Version de production (fichiers statiques dans `build/web`, à servir par n'importe quel serveur web, ~3 min) :

```powershell
..\.tools\flutter\bin\flutter build web --dart-define=API_URL=https://api.transconnect.app
```

Connexion : numéro d'un compte **administrateur** (démo : `+22990000001`), puis le code OTP.
En développement (`OTP_DEBUG=1` côté API), le code s'affiche sous le champ.
Les autres rôles sont refusés. L'API limite à **3 codes par numéro sur 15 minutes**.

## Écrans

| Écran | Fonctions |
|---|---|
| Tableau de bord | Demandes, transporteurs actifs, marchands, chiffre d'affaires (évolution vs période précédente) ; période 7 j / 30 j / 12 mois ; export CSV ; demandes par jour (14 j) ; conversion devis → paiement ; délai moyen d'évaluation ; zones actives ; demandes récentes |
| Utilisateurs | Liste filtrable (rôle, statut, nom) ; fiche avec validation / suspension et documents KYC ; création de comptes représentant, chauffeur, admin ; onglet de vérification KYC |
| Transporteurs | Liste ; fiche avec flotte, grille tarifaire, équipe ; validation, suspension, abonnement ; création |
| Demandes | Suivi de toutes les demandes (statut, n°, marchand) ; fiche détaillée avec historique des statuts |
| Paiements | Filtre statut / séquestre ; confirmation manuelle, échec, libération des fonds, remboursement |
| Litiges | Prise en charge et décision (remboursement total / partiel, libération) |
| Config | Villes desservies (ajout, activation) |
| Rapports | Objectifs du cahier des charges, demandes par statut, zones actives |

La barre de recherche du haut ouvre une demande (numéro) ou un utilisateur (nom).

## Structure

```
lib/
  main.dart            routes (go_router) et redirection vers /connexion
  theme.dart           design system : couleurs, typographie, rayons, statuts
  api/api_client.dart  appels JSON-LD, JWT, renouvellement automatique sur 401
  auth/                session admin (OTP, jetons dans le navigateur)
  widgets/             mise en page, cartes KPI, badges, tableau paginé, graphiques
  pages/               un fichier par écran
```

## API utilisée

Ressources standard (`/api/utilisateurs`, `/api/paiements`…) plus deux ressources dédiées au back-office,
réservées aux admins : `GET /api/admin/tableau-de-bord` (indicateurs) et `/api/suivi_demandes`
(vue SQL `v_suivi_demande`).
