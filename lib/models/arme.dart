/// Une arme du parc.
class Arme {
  int? id;
  String numeroSerie;
  int? typeArmeId;
  String? typeLibelle;
  String? calibre;
  String? marque;
  String etat;
  String? localisation;

  Arme({
    this.id,
    required this.numeroSerie,
    this.typeArmeId,
    this.typeLibelle,
    this.calibre,
    this.marque,
    this.etat = 'EN_SERVICE',
    this.localisation,
  });

  factory Arme.fromMap(Map<String, Object?> m) => Arme(
        id: m['id'] as int?,
        numeroSerie: (m['numero_serie'] ?? '') as String,
        typeArmeId: m['type_arme_id'] as int?,
        typeLibelle: m['type_libelle'] as String?,
        calibre: m['calibre'] as String?,
        marque: m['marque'] as String?,
        etat: (m['etat'] ?? 'EN_SERVICE') as String,
        localisation: m['localisation'] as String?,
      );

  bool get disponible => etat == 'EN_SERVICE';
}

/// Munition en stock.
class Munition {
  int? id;
  String typeCalibre;
  String designation;
  int stockActuel;
  int seuilAlerte;
  String unite;

  Munition({
    this.id,
    required this.typeCalibre,
    required this.designation,
    this.stockActuel = 0,
    this.seuilAlerte = 0,
    this.unite = 'unite',
  });

  factory Munition.fromMap(Map<String, Object?> m) => Munition(
        id: m['id'] as int?,
        typeCalibre: (m['type_calibre'] ?? '') as String,
        designation: (m['designation'] ?? '') as String,
        stockActuel: (m['stock_actuel'] as int?) ?? 0,
        seuilAlerte: (m['seuil_alerte'] as int?) ?? 0,
        unite: (m['unite'] ?? 'unite') as String,
      );

  bool get enAlerte => stockActuel <= seuilAlerte;
}

/// Mouvement d'armurerie (entree / sortie).
class Mouvement {
  int? id;
  String sens;
  int? armeId;
  String? armeNumero;
  int? munitionId;
  String? munitionDesignation;
  int quantite;
  String dateHeure;
  String? motif;
  String? referenceOrdre;
  int? beneficiaireId;
  String? beneficiaireNom;
  String? statutValidation;

  Mouvement({
    this.id,
    required this.sens,
    this.armeId,
    this.armeNumero,
    this.munitionId,
    this.munitionDesignation,
    this.quantite = 1,
    required this.dateHeure,
    this.motif,
    this.referenceOrdre,
    this.beneficiaireId,
    this.beneficiaireNom,
    this.statutValidation = 'VALIDE',
  });

  factory Mouvement.fromMap(Map<String, Object?> m) => Mouvement(
        id: m['id'] as int?,
        sens: (m['sens'] ?? 'SORTIE') as String,
        armeId: m['arme_id'] as int?,
        armeNumero: m['arme_numero'] as String?,
        munitionId: m['munition_id'] as int?,
        munitionDesignation: m['munition_designation'] as String?,
        quantite: (m['quantite'] as int?) ?? 1,
        dateHeure: (m['date_heure'] ?? '') as String,
        motif: m['motif'] as String?,
        referenceOrdre: m['reference_ordre'] as String?,
        beneficiaireId: m['beneficiaire_id'] as int?,
        beneficiaireNom: m['beneficiaire_nom'] as String?,
        statutValidation: m['statut_validation'] as String?,
      );
}

extension MouvementMap on Mouvement {
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'sens': sens,
        'arme_id': armeId,
        'munition_id': munitionId,
        'quantite': quantite,
        'date_heure': dateHeure,
        'motif': motif,
        'reference_ordre': referenceOrdre,
        'beneficiaire_id': beneficiaireId,
        'statut_validation': statutValidation,
      };
}
