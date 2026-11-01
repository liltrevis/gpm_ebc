# GPM-2EBC

Application mobile Flutter de **Gestion du Personnel Militaire** du **2e Escadron
Blinde de Combat (2e EBC)**. Fonctionne **hors-ligne** (base SQLite locale), avec
exports PDF/Excel, gestion des effectifs, des services et du parc d'armement.

## Fonctionnalites

- Authentification + RBAC (Admin, Commandant d'unite, Secretariat RH, Armurier, Chef de section, Consultation).
- Tableau de bord du Commandant : effectif total, disponible/indisponible, repartition par statut et par section, parc d'armement, taux de disponibilite, actions rapides.
- Effectifs : recherche, filtres (section, statut), fiche detaillee, creation/modification, changement de statut.
- Services : planification des gardes/patrouilles, selection equitable automatique, validation, suivi des presences.
- Armement: parc (armes), munitions (avec seuil d'alerte), mouvements (sortie/entree) et dotations.
- Rapports: generation et historisation de l'etat quotidien, exports PDF et Excel.
- Hors-ligne : toutes les ecritures sont journalisees (audit) et mises en file (`sync_outbox`).

## Prerequis

- Flutter SDK stable (>= 3.22, recommande 3.27+). Installation : https://docs.flutter.dev/get-started/install
- Un appareil ou emulateur Android (l'application utilise SQLite via `sqflite`).

## Mise en route

Depuis le dossier `gpm_ebc` :

```
flutter create .          # genere les dossiers android/ios/web manquants
flutter pub get
flutter run
```

Comptes de demonstration :

| Identifiant | Mot de passe | Role                 |
|-------------|--------------|----------------------|
| admin       | admin123     | Administrateur       |
| cmd         | cmd123       | Commandant d'unite   |
| rh          | rh123        | Secretariat RH       |
| armurier    | arm123       | Armurier             |
| section     | sec123       | Chef de section      |

## Structure

- `lib/core/` : constantes, RBAC, theme, formatage.
- `lib/data/` : base SQLite (schema + jeu de donnees reel), depots, journal d'audit.
- `lib/models/` : modeles (personnel, service, armement, utilisateur).
- `lib/providers/` : gestion d'etat (provider).
- `lib/screens/` : ecrans (connexion, tableau de bord, effectifs, services, armement, rapports, admin).
- `lib/services/` : exports PDF et Excel.
- `docs/` (a la racine du projet) : cahier des charges, schema BDD, architecture.

## Notes

- Les mots de passe sont stockes en SHA-256 (demonstration) ; utiliser bcrypt/argon2 avec sel en production.
- La synchronisation serveur est simulee (aucun backend dans cette version) ; la table `sync_outbox` est prete pour une implementation reseau.
