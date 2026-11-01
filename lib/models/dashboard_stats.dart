/// Une personne concernee par une position (detail du tableau de bord).
class PersonnePosition {
  final String nom;
  final String? debut;
  final String? duree;
  PersonnePosition({required this.nom, this.debut, this.duree});
}

/// Repartition d'une precision de position.
class PrecisionStats {
  final String libelle;
  final int total;
  final List<PersonnePosition> personnes;
  PrecisionStats({
    required this.libelle,
    required this.total,
    this.personnes = const [],
  });
}

/// Repartition d'une rubrique (position principale) et de ses precisions.
class RubriqueStats {
  final String libelle;
  final int total;
  final List<PrecisionStats> precisions;
  RubriqueStats({
    required this.libelle,
    required this.total,
    required this.precisions,
  });

  /// Vrai si au moins une precision reelle (hors "Sans précision").
  bool get aDesPrecisions =>
      precisions.any((p) => p.libelle != 'Sans précision');
}

/// Statistiques affichees sur le tableau de bord du Commandant.
class SectionStats {
  final int sectionId;
  final String libelle;
  final int effectif;
  final int disponible;
  SectionStats({
    required this.sectionId,
    required this.libelle,
    required this.effectif,
    required this.disponible,
  });
}

class DashboardStats {
  int effectifTotal = 0;
  int presents = 0;
  int mission = 0;
  int stage = 0;
  int miseADisposition = 0;
  int permission = 0;
  int malades = 0;
  int reposMedical = 0;
  int absent = 0;
  int indisponible = 0;
  int disponible = 0;

  int armesTotal = 0;
  int armesEnService = 0;
  int armesDefectueuses = 0;
  int armesDotees = 0;
  int munitionsAlerte = 0;

  int servicesDuJour = 0;
  int outboxEnAttente = 0;

  List<SectionStats> parSection = [];

  /// Repartition par position principale, avec precisions imbriquees et
  /// personnes concernees (debut / duree).
  List<RubriqueStats> repartition = [];

  RubriqueStats? rubrique(String libelle) {
    for (final r in repartition) {
      if (r.libelle == libelle) return r;
    }
    return null;
  }

  double get tauxDisponibilite =>
      effectifTotal == 0 ? 0 : (disponible / effectifTotal) * 100;
}
