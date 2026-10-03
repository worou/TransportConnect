# TransportConnect – application mobile (Flutter)

Une seule application, deux espaces choisis à la connexion (code OTP par SMS) :

| Espace | Écrans (maquettes) |
|---|---|
| **Marchand** | Connexion (M02, M03), accueil (M04), nouvelle demande en 4 étapes (M05–M07), suivi (M08), estimation et négociation (M09), paiement (M10, M11), suivi sur carte et code de réception (M12), messages, profil (M13) |
| **Représentant** | Accueil et disponibilité (R01), missions de la zone (R02), détail (R03), évaluation sur site : check-in GPS, pesée et photos, prix calculé avec ajustement ±20 % (R04–R06), activité (R07), profil |

Un compte chauffeur voit un écran d'attente (pas encore d'espace dédié).

## Construire l'APK Android

Outils portables dans `../.tools` (Flutter, JDK 21, SDK Android 36, NDK 28.2) :

```powershell
cd mobile
$env:JAVA_HOME = "..\.tools\jdk-21.0.12.1+1"
..\.tools\flutter\bin\flutter build apk --release --dart-define=API_URL=https://transco.teranga.re
# → build\app\outputs\flutter-apk\app-release.apk
```

APK plus légers, un par type de processeur : `--split-per-abi` (≈ 20 Mo chacun).

L'APK est signé avec la clé de débogage : il s'installe directement sur un téléphone
(« sources inconnues »), mais **une clé de signature dédiée est obligatoire pour le Play Store**
(fichier `.jks` et `key.properties`, à ne jamais versionner).

## Tester sans téléphone

La même app se construit pour le web, contre l'API locale (CORS autorisé pour localhost) :

```powershell
..\.tools\flutter\bin\flutter build web --dart-define=API_URL=http://127.0.0.1:8000 --output build/web-local
python -m http.server 8081 --directory build/web-local
```

## Points d'attention

- **Codes OTP** : tant que `OTP_DEBUG=1` côté API, le code s'affiche dans l'app (« Version de test »).
  N'importe qui connaissant un numéro peut alors se connecter : à désactiver avant toute diffusion.
- **Paiement** : aucun prestataire (CinetPay, Wave…) n'est encore branché ; le paiement reste « en attente de
  confirmation » jusqu'à sa validation dans le back-office.
- **Distance** : estimée à partir des coordonnées des deux villes (× 1,25), faute de calcul d'itinéraire.
- **Carte** : tuiles OpenStreetMap (usage modéré ; prévoir un fournisseur de tuiles en cas de trafic important).
