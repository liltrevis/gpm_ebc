import 'package:flutter/foundation.dart';

import '../data/armement_repository.dart';
import '../models/app_user.dart';
import '../models/arme.dart';

/// Etat du parc d'armement.
class ArmementProvider extends ChangeNotifier {
  final ArmementRepository _repo;
  ArmementProvider(this._repo);

  List<Arme> armes = [];
  List<Munition> munitions = [];
  List<Mouvement> mouvements = [];
  bool loading = false;
  String? filtreEtat;

  Future<void> charger() async {
    loading = true;
    notifyListeners();
    try {
      armes = await _repo.armes(etat: filtreEtat);
      munitions = await _repo.munitions();
      mouvements = await _repo.mouvements();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> enregistrerMouvement(
    Mouvement m, {
    String? etatRetour,
    AppUser? acteur,
  }) async {
    await _repo.enregistrerMouvement(m,
        etatRetour: etatRetour, utilisateurId: acteur?.id, utilisateurNom: acteur?.nomComplet);
    await charger();
  }
}
