/// Modele d'un militaire (avec libelles joints pour l'affichage).
class Personnel {
  int? id;
  int? gradeId;
  String nomPrenoms;
  String? matricule;
  String? mecano;
  int? escadronId;
  String? position;
  String? positionPrecision;
  String? positionDebut;
  String? positionDuree;
  String? dateNaissance;
  String? lieuNaissance;
  String? nomPere;
  String? nomMere;
  int? categorieId;
  String? genre;
  int? situationMatrimonialeId;
  String? dateDebutService;
  String? dateNomination;
  String? referenceNomination;
  String? dateArriveeCorps;
  String? dateEffet;
  String? uniteProvenance;
  String? referenceAffectation;
  String? dateAffectation;
  String? nouvelleUniteAffectation;
  String? reference;
  int? domaineId;
  String? diplomeMilitaire;
  String? decision;
  String? diplomeCivil;
  String? niveauEtude;
  String? nomConjoint;
  int? nombreEnfants;
  String? personneAppeler;
  String? telephone;
  String? numeroCim;
  String? cni;
  String? nni;
  String? passeport;
  String? mugfci;
  String? fpm;
  String? cmu;
  int? groupeSanguinId;
  String? lieuHabitation;
  String? livretMatricule;
  String? dossierPension;
  String? droitDossierPension;
  String? situationDossier;
  String? promotionClasse;
  double? taille;
  int actif;

  // Champs joints (lecture seule).
  int? sectionId;
  int? fonctionId;
  String? gradeCode;
  String? gradeLibelle;
  String? categorieLibelle;
  String? sectionLibelle;
  String? fonctionLibelle;
  int? statutId;
  String? statutCode;
  String? statutLibelle;
  String? statutStatutRapport;
  bool disponible;
  String? escadronCode;
  String? escadronLibelle;
  String? situationMatrimonialeLibelle;
  String? domaineLibelle;
  String? groupeSanguinCode;

  Personnel({
    this.id,
    this.gradeId,
    required this.nomPrenoms,
    this.matricule,
    this.mecano,
    this.escadronId,
    this.position,
    this.positionPrecision,
    this.positionDebut,
    this.positionDuree,
    this.dateNaissance,
    this.lieuNaissance,
    this.nomPere,
    this.nomMere,
    this.categorieId,
    this.genre,
    this.situationMatrimonialeId,
    this.dateDebutService,
    this.dateNomination,
    this.referenceNomination,
    this.dateArriveeCorps,
    this.dateEffet,
    this.uniteProvenance,
    this.referenceAffectation,
    this.dateAffectation,
    this.nouvelleUniteAffectation,
    this.reference,
    this.domaineId,
    this.diplomeMilitaire,
    this.decision,
    this.diplomeCivil,
    this.niveauEtude,
    this.nomConjoint,
    this.nombreEnfants,
    this.personneAppeler,
    this.telephone,
    this.numeroCim,
    this.cni,
    this.nni,
    this.passeport,
    this.mugfci,
    this.fpm,
    this.cmu,
    this.groupeSanguinId,
    this.lieuHabitation,
    this.livretMatricule,
    this.dossierPension,
    this.droitDossierPension,
    this.situationDossier,
    this.promotionClasse,
    this.taille,
    this.actif = 1,
    this.gradeLibelle,
    this.statutLibelle,
    this.disponible = false,
  });

  Personnel.nouveau()
      : nomPrenoms = '',
        actif = 1,
        disponible = false;

  factory Personnel.fromMap(Map<String, Object?> m) {
    final p = Personnel(
      id: m['id'] as int?,
      gradeId: m['grade_id'] as int?,
      nomPrenoms: (m['nom_prenoms'] ?? '') as String,
      matricule: m['matricule'] as String?,
      mecano: m['mecano'] as String?,
      escadronId: m['escadron_id'] as int?,
      position: m['position'] as String?,
      positionPrecision: m['position_precision'] as String?,
      positionDebut: m['position_debut'] as String?,
      positionDuree: m['position_duree'] as String?,
      dateNaissance: m['date_naissance'] as String?,
      lieuNaissance: m['lieu_naissance'] as String?,
      nomPere: m['nom_pere'] as String?,
      nomMere: m['nom_mere'] as String?,
      categorieId: m['categorie_id'] as int?,
      genre: m['genre'] as String?,
      situationMatrimonialeId: m['situation_matrimoniale_id'] as int?,
      dateDebutService: m['date_debut_service'] as String?,
      dateNomination: m['date_nomination'] as String?,
      referenceNomination: m['reference_nomination'] as String?,
      dateArriveeCorps: m['date_arrivee_corps'] as String?,
      dateEffet: m['date_effet'] as String?,
      uniteProvenance: m['unite_provenance'] as String?,
      referenceAffectation: m['reference_affectation'] as String?,
      dateAffectation: m['date_affectation'] as String?,
      nouvelleUniteAffectation: m['nouvelle_unite_affectation'] as String?,
      reference: m['reference'] as String?,
      domaineId: m['domaine_id'] as int?,
      diplomeMilitaire: m['diplome_militaire'] as String?,
      decision: m['decision'] as String?,
      diplomeCivil: m['diplome_civil'] as String?,
      niveauEtude: m['niveau_etude'] as String?,
      nomConjoint: m['nom_conjoint'] as String?,
      nombreEnfants: m['nombre_enfants'] as int?,
      personneAppeler: m['personne_appeler'] as String?,
      telephone: m['telephone'] as String?,
      numeroCim: m['numero_cim'] as String?,
      cni: m['cni'] as String?,
      nni: m['nni'] as String?,
      passeport: m['passeport'] as String?,
      mugfci: m['mugfci'] as String?,
      fpm: m['fpm'] as String?,
      cmu: m['cmu'] as String?,
      groupeSanguinId: m['groupe_sanguin_id'] as int?,
      lieuHabitation: m['lieu_habitation'] as String?,
      livretMatricule: m['livret_matricule'] as String?,
      dossierPension: m['dossier_pension'] as String?,
      droitDossierPension: m['droit_dossier_pension'] as String?,
      situationDossier: m['situation_dossier'] as String?,
      promotionClasse: m['promotion_classe'] as String?,
      taille: (m['taille'] as num?)?.toDouble(),
      actif: (m['actif'] as int?) ?? 1,
      gradeLibelle: m['grade_libelle'] as String?,
      statutLibelle: m['statut_libelle'] as String?,
    );
    p.gradeCode = m['grade_code'] as String?;
    p.sectionId = m['section_id'] as int?;
    p.fonctionId = m['fonction_id'] as int?;
    p.categorieLibelle = m['categorie_libelle'] as String?;
    p.sectionLibelle = m['section_libelle'] as String?;
    p.fonctionLibelle = m['fonction_libelle'] as String?;
    p.statutCode = m['statut_code'] as String?;
    p.statutId = m['statut_id'] as int?;
    p.disponible = ((m['statut_disponible'] as int?) ?? 0) == 1;
    p.escadronCode = m['escadron_code'] as String?;
    p.escadronLibelle = m['escadron_libelle'] as String?;
    p.situationMatrimonialeLibelle =
        m['situation_matrimoniale_libelle'] as String?;
    p.domaineLibelle = m['domaine_libelle'] as String?;
    p.groupeSanguinCode = m['groupe_sanguin_code'] as String?;
    return p;
  }
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'grade_id': gradeId,
      'nom_prenoms': nomPrenoms,
      'matricule': matricule,
      'mecano': mecano,
      'escadron_id': escadronId,
      'position': position,
      'position_precision': positionPrecision,
      'position_debut': positionDebut,
      'position_duree': positionDuree,
      'date_naissance': dateNaissance,
      'lieu_naissance': lieuNaissance,
      'nom_pere': nomPere,
      'nom_mere': nomMere,
      'categorie_id': categorieId,
      'genre': genre,
      'situation_matrimoniale_id': situationMatrimonialeId,
      'date_debut_service': dateDebutService,
      'date_nomination': dateNomination,
      'reference_nomination': referenceNomination,
      'date_arrivee_corps': dateArriveeCorps,
      'date_effet': dateEffet,
      'unite_provenance': uniteProvenance,
      'reference_affectation': referenceAffectation,
      'date_affectation': dateAffectation,
      'nouvelle_unite_affectation': nouvelleUniteAffectation,
      'reference': reference,
      'domaine_id': domaineId,
      'diplome_militaire': diplomeMilitaire,
      'decision': decision,
      'diplome_civil': diplomeCivil,
      'niveau_etude': niveauEtude,
      'nom_conjoint': nomConjoint,
      'nombre_enfants': nombreEnfants,
      'personne_appeler': personneAppeler,
      'telephone': telephone,
      'numero_cim': numeroCim,
      'cni': cni,
      'nni': nni,
      'passeport': passeport,
      'mugfci': mugfci,
      'fpm': fpm,
      'cmu': cmu,
      'groupe_sanguin_id': groupeSanguinId,
      'lieu_habitation': lieuHabitation,
      'livret_matricule': livretMatricule,
      'dossier_pension': dossierPension,
      'droit_dossier_pension': droitDossierPension,
      'situation_dossier': situationDossier,
      'promotion_classe': promotionClasse,
      'taille': taille,
      'actif': actif,
    };
  }

  bool get nomCompletEstVide => nomPrenoms.trim().isEmpty;
}
