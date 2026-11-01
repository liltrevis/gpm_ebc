import 'package:flutter/foundation.dart';

/// Signale a la racine de l'application qu'il faut recharger toutes les
/// donnees (ex. apres un import de sauvegarde). Les fournisseurs (providers)
/// sont alors recrees sur la base nouvellement en place.
final ValueNotifier<int> _rechargement = ValueNotifier<int>(0);

ValueListenable<int> get signalRechargement => _rechargement;

/// Declenche un rechargement complet de l'application.
void rechargerApplication() => _rechargement.value++;
