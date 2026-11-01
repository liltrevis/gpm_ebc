import '../models/personnel.dart';
import 'format.dart';

/// Colonnes selectionnables pour l'export d'un etat.
///
/// Les colonnes correspondent aux informations presentes dans la base de
/// donnees de reference (BASE DE DONNEES 2eEBC).
class ColonneEtat {
  final String cle;
  final String libelle;
  final bool parDefaut;
  final String Function(Map<String, Object?> concernes) valeur;

  const ColonneEtat({
    required this.cle,
    required this.libelle,
    required this.valeur,
    this.parDefaut = false,
  });
}

String _txt(Object? v) => v?.toString() ?? '';

String _date(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? '' : formatDateFr(s);
}

/// Texte "Position (precision)" ou, a defaut, le statut de la personne.
String positionTexte(Map<String, Object?> c) {
  final position = (c['position'] ?? '').toString().trim();
  final precision = (c['precision'] ?? '').toString().trim();
  if (position.isNotEmpty) {
    return precision.isEmpty ? position : '$position ($precision)';
  }
  return (c['statut'] ?? '').toString();
}

/// Colonnes disponibles pour les exports (PDF / Excel) d'un etat.
/// L'ordre et les libelles suivent celui de la base de donnees de reference.
final List<ColonneEtat> kColonnesEtat = [
  ColonneEtat(
    cle: 'numero',
    libelle: 'N°',
    parDefaut: true,
    valeur: (c) => '${c['ordre'] ?? ''}',
  ),
  ColonneEtat(
    cle: 'grade',
    libelle: 'GRADE',
    parDefaut: true,
    valeur: (c) => _txt(c['grade']),
  ),
  ColonneEtat(
    cle: 'nom',
    libelle: 'NOMS ET PRENOMS',
    parDefaut: true,
    valeur: (c) => _txt(c['nom']),
  ),
  ColonneEtat(
    cle: 'matricule',
    libelle: 'MATRICULE',
    valeur: (c) => _txt(c['matricule']),
  ),
  ColonneEtat(cle: 'mecano', libelle: 'MECANO', valeur: (c) => _txt(c['mecano'])),
  ColonneEtat(
    cle: 'escadron',
    libelle: 'ESCADRON',
    valeur: (c) => _txt(c['escadron']),
  ),
  ColonneEtat(
    cle: 'peloton',
    libelle: 'PELOTON',
    valeur: (c) => _txt(c['peloton']),
  ),
  ColonneEtat(
    cle: 'fonction',
    libelle: 'FONCTION',
    valeur: (c) => _txt(c['fonction']),
  ),
  ColonneEtat(
    cle: 'position',
    libelle: 'POSITION',
    valeur: positionTexte,
  ),
  ColonneEtat(
    cle: 'date_naissance',
    libelle: 'DATE DE NAISSANCE',
    valeur: (c) => _date(c['date_naissance']),
  ),
  ColonneEtat(
    cle: 'lieu_naissance',
    libelle: 'LIEU DE NAISSANCE',
    valeur: (c) => _txt(c['lieu_naissance']),
  ),
  ColonneEtat(
    cle: 'nom_pere',
    libelle: 'NOM DU PERE',
    valeur: (c) => _txt(c['nom_pere']),
  ),
  ColonneEtat(
    cle: 'nom_mere',
    libelle: 'NOM DE LA MERE',
    valeur: (c) => _txt(c['nom_mere']),
  ),
  ColonneEtat(
    cle: 'categorie',
    libelle: 'CATEGORIE',
    valeur: (c) => _txt(c['categorie']),
  ),
  ColonneEtat(cle: 'genre', libelle: 'GENRE', valeur: (c) => _txt(c['genre'])),
  ColonneEtat(
    cle: 'situation_matrimoniale',
    libelle: 'SITUATION MATRIMONIALE',
    valeur: (c) => _txt(c['situation_matrimoniale']),
  ),
  ColonneEtat(
    cle: 'date_debut_service',
    libelle: 'DATE DEBUT SERVICE',
    valeur: (c) => _date(c['date_debut_service']),
  ),
  ColonneEtat(
    cle: 'date_nomination',
    libelle: 'DATE DE NOMINATION',
    valeur: (c) => _date(c['date_nomination']),
  ),
  ColonneEtat(
    cle: 'reference_nomination',
    libelle: 'REFERENCE DE NOMINATION',
    valeur: (c) => _txt(c['reference_nomination']),
  ),
  ColonneEtat(
    cle: 'date_arrivee_corps',
    libelle: "DATE D'ARRIVEE AU CORPS",
    valeur: (c) => _date(c['date_arrivee_corps']),
  ),
  ColonneEtat(
    cle: 'date_effet',
    libelle: "DATE D'EFFET",
    valeur: (c) => _date(c['date_effet']),
  ),
  ColonneEtat(
    cle: 'unite_provenance',
    libelle: 'UNITE DE PROVENANCE',
    valeur: (c) => _txt(c['unite_provenance']),
  ),
  ColonneEtat(
    cle: 'reference_affectation',
    libelle: "REFERENCE D'AFFECTATION",
    valeur: (c) => _txt(c['reference_affectation']),
  ),
  ColonneEtat(
    cle: 'date_affectation',
    libelle: "DATE D'AFFECTATION DE L'UNITE / RADIATION OU DECES",
    valeur: (c) => _date(c['date_affectation']),
  ),
  ColonneEtat(
    cle: 'nouvelle_unite_affectation',
    libelle: "NOUVELLE UNITE D'AFFECTATION / LIEU DE DECES",
    valeur: (c) => _txt(c['nouvelle_unite_affectation']),
  ),
  ColonneEtat(
    cle: 'reference',
    libelle: 'REFERENCE',
    valeur: (c) => _txt(c['reference']),
  ),
  ColonneEtat(
    cle: 'domaine',
    libelle: 'DOMAINE',
    valeur: (c) => _txt(c['domaine']),
  ),
  ColonneEtat(
    cle: 'diplome_militaire',
    libelle: 'DIPLOME MILITAIRE',
    valeur: (c) => _txt(c['diplome_militaire']),
  ),
  ColonneEtat(
    cle: 'decision',
    libelle: 'DECISION',
    valeur: (c) => _txt(c['decision']),
  ),
  ColonneEtat(
    cle: 'diplome_civil',
    libelle: 'DIPLOME CIVIL',
    valeur: (c) => _txt(c['diplome_civil']),
  ),
  ColonneEtat(
    cle: 'niveau_etude',
    libelle: "NIVEAU D'ETUDE",
    valeur: (c) => _txt(c['niveau_etude']),
  ),
  ColonneEtat(
    cle: 'nom_conjoint',
    libelle: 'NOM CONJOINT',
    valeur: (c) => _txt(c['nom_conjoint']),
  ),
  ColonneEtat(
    cle: 'nombre_enfants',
    libelle: "NBRE D'ENFANT",
    valeur: (c) => _txt(c['nombre_enfants']),
  ),
  ColonneEtat(
    cle: 'personne_appeler',
    libelle: 'PERSONNE A APPELER EN CAS D\'URGENCE',
    valeur: (c) => _txt(c['personne_appeler']),
  ),
  ColonneEtat(
    cle: 'telephone',
    libelle: 'N° TELEPHONE',
    valeur: (c) => _txt(c['telephone']),
  ),
  ColonneEtat(
    cle: 'numero_cim',
    libelle: 'N° CIM',
    valeur: (c) => _txt(c['numero_cim']),
  ),
  ColonneEtat(cle: 'cni', libelle: 'CNI', valeur: (c) => _txt(c['cni'])),
  ColonneEtat(cle: 'nni', libelle: 'NNI', valeur: (c) => _txt(c['nni'])),
  ColonneEtat(
    cle: 'passeport',
    libelle: 'PASSEPORT',
    valeur: (c) => _txt(c['passeport']),
  ),
  ColonneEtat(
    cle: 'mugfci',
    libelle: 'MUGEFCI',
    valeur: (c) => _txt(c['mugfci']),
  ),
  ColonneEtat(cle: 'fpm', libelle: 'FPM', valeur: (c) => _txt(c['fpm'])),
  ColonneEtat(cle: 'cmu', libelle: 'CMU', valeur: (c) => _txt(c['cmu'])),
  ColonneEtat(
    cle: 'groupe_sanguin',
    libelle: 'GROUPE SANGUIN',
    valeur: (c) => _txt(c['groupe_sanguin']),
  ),
  ColonneEtat(
    cle: 'lieu_habitation',
    libelle: "LIEU D'HABITATION",
    valeur: (c) => _txt(c['lieu_habitation']),
  ),
  ColonneEtat(
    cle: 'livret_matricule',
    libelle: 'LIVRET MATRICULE',
    valeur: (c) => _txt(c['livret_matricule']),
  ),
  ColonneEtat(
    cle: 'dossier_pension',
    libelle: 'DOSSIER DE PENSION',
    valeur: (c) => _txt(c['dossier_pension']),
  ),
  ColonneEtat(
    cle: 'droit_dossier_pension',
    libelle: 'DROIT A DOSSIER DE PENSION',
    valeur: (c) => _txt(c['droit_dossier_pension']),
  ),
  ColonneEtat(
    cle: 'situation_dossier',
    libelle: 'SITUATION DOSSIER',
    valeur: (c) => _txt(c['situation_dossier']),
  ),
  ColonneEtat(
    cle: 'promotion_classe',
    libelle: 'PROMOTION OU CLASSE',
    valeur: (c) => _txt(c['promotion_classe']),
  ),
  ColonneEtat(
    cle: 'taille',
    libelle: 'TAILLE',
    valeur: (c) => _txt(c['taille']),
  ),
];

/// Colonnes cochees par defaut.
List<ColonneEtat> colonnesParDefaut() =>
    kColonnesEtat.where((c) => c.parDefaut).toList();

/// Construit l'instantané (map) d'un militaire pour un etat.
Map<String, Object?> concernesDepuisPersonnel(
  Personnel p,
  int ordre, {
  String? position,
  String? precision,
}) {
  return {
    'ordre': ordre,
    'grade': p.gradeCode ?? p.gradeLibelle ?? '',
    'nom': p.nomPrenoms,
    'matricule': p.matricule ?? '',
    'mecano': p.mecano ?? '',
    'escadron': p.escadronCode ?? p.escadronLibelle ?? '',
    'peloton': p.sectionLibelle ?? '',
    'fonction': p.fonctionLibelle ?? '',
    'position': position ?? '',
    'precision': precision,
    'statut': p.statutLibelle ?? '',
    'date_naissance': p.dateNaissance,
    'lieu_naissance': p.lieuNaissance,
    'nom_pere': p.nomPere,
    'nom_mere': p.nomMere,
    'categorie': p.categorieLibelle,
    'genre': p.genre,
    'situation_matrimoniale': p.situationMatrimonialeLibelle,
    'date_debut_service': p.dateDebutService,
    'date_nomination': p.dateNomination,
    'reference_nomination': p.referenceNomination,
    'date_arrivee_corps': p.dateArriveeCorps,
    'date_effet': p.dateEffet,
    'unite_provenance': p.uniteProvenance,
    'reference_affectation': p.referenceAffectation,
    'date_affectation': p.dateAffectation,
    'nouvelle_unite_affectation': p.nouvelleUniteAffectation,
    'reference': p.reference,
    'domaine': p.domaineLibelle,
    'diplome_militaire': p.diplomeMilitaire,
    'decision': p.decision,
    'diplome_civil': p.diplomeCivil,
    'niveau_etude': p.niveauEtude,
    'nom_conjoint': p.nomConjoint,
    'nombre_enfants': p.nombreEnfants,
    'personne_appeler': p.personneAppeler,
    'telephone': p.telephone,
    'numero_cim': p.numeroCim,
    'cni': p.cni,
    'nni': p.nni,
    'passeport': p.passeport,
    'mugfci': p.mugfci,
    'fpm': p.fpm,
    'cmu': p.cmu,
    'groupe_sanguin': p.groupeSanguinCode,
    'lieu_habitation': p.lieuHabitation,
    'livret_matricule': p.livretMatricule,
    'dossier_pension': p.dossierPension,
    'droit_dossier_pension': p.droitDossierPension,
    'situation_dossier': p.situationDossier,
    'promotion_classe': p.promotionClasse,
    'taille': p.taille,
  };
}
