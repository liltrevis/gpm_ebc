/// Element de referentiel generique (id + code + libelle).
class RefItem {
  final int id;
  final String code;
  final String libelle;
  final String? extra;

  /// Code de la categorie statutaire (uniquement pour les grades).
  final String? categorieCode;

  RefItem({
    required this.id,
    required this.code,
    required this.libelle,
    this.extra,
    this.categorieCode,
  });

  factory RefItem.fromMap(Map<String, Object?> m) => RefItem(
        id: (m['id'] as int?) ?? 0,
        code: (m['code'] ?? '') as String,
        libelle: (m['libelle'] ?? '') as String,
        extra: m['calibre'] as String?,
        categorieCode: m['categorie_code'] as String?,
      );

  @override
  String toString() => libelle;
}

/// Statut avec indicateur de disponibilite (pour rapports).
class StatutItem {
  final int id;
  final String code;
  final String libelle;
  final String libelleRapport;
  final bool disponible;

  StatutItem({
    required this.id,
    required this.code,
    required this.libelle,
    required this.libelleRapport,
    required this.disponible,
  });

  factory StatutItem.fromMap(Map<String, Object?> m) => StatutItem(
        id: (m['id'] as int?) ?? 0,
        code: (m['code'] ?? '') as String,
        libelle: (m['libelle'] ?? '') as String,
        libelleRapport: (m['libelle_rapport'] ?? '') as String,
        disponible: ((m['disponible'] as int?) ?? 0) == 1,
      );

  @override
  String toString() => libelle;
}
