import 'package:flutter/foundation.dart';

import '../data/rapport_repository.dart';
import '../models/dashboard_stats.dart';
import '../models/spa.dart';

/// Etat du tableau de bord du Commandant.
class DashboardProvider extends ChangeNotifier {
  final RapportRepository _repo;
  DashboardProvider(this._repo);

  DashboardStats stats = DashboardStats();
  bool loading = false;

  /// Peloton impose par le compte connecte (Chef de Peloton), sinon null.
  int? perimetreSectionId;

  /// Applique (ou retire) le perimetre du compte et recharge le tableau de bord.
  void definirPerimetre(int? sectionId) {
    if (perimetreSectionId == sectionId) return;
    perimetreSectionId = sectionId;
    charger();
  }

  Future<void> supprimerEtat(
    int id, {
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    await _repo.supprimerEtat(id,
        utilisateurId: utilisateurId, utilisateurNom: utilisateurNom);
  }

  Future<void> charger() async {
    loading = true;
    notifyListeners();
    try {
      stats = await _repo.tableauDeBord(sectionId: perimetreSectionId);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Detail des rubriques de repartition pour un peloton donne
  /// (tableau de bord developpe au choix sur la carte du peloton).
  Future<DashboardStats> detailSection(int sectionId) =>
      _repo.tableauDeBord(sectionId: sectionId);

  Future<int> genererEtat({
    required String type,
    String? nom,
    String? duree,
    Map<String, int>? composition,
    List<String>? statutCodes,
    bool? disponible,
    List<Map<String, Object?>>? concernes,
    int? utilisateurId,
  }) async {
    final id = await _repo.enregistrerEtatQuotidien(
      type: type,
      nom: nom,
      duree: duree,
      composition: composition,
      statutCodes: statutCodes,
      disponible: disponible,
      concernes: concernes,
      utilisateurId: utilisateurId,
      sectionId: perimetreSectionId,
    );
    await charger();
    return id;
  }

  Future<List<Map<String, Object?>>> historique() =>
      _repo.historiqueEtats(sectionId: perimetreSectionId);

  /// Document SPA (Situation des Personnels Absents) calcule automatiquement.
  Future<SpaData> spa() => _repo.situationSpa(sectionId: perimetreSectionId);
}
