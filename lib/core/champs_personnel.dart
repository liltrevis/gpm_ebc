/// Champs modifiables en masse sur les fiches du personnel.
///
/// Les libelles et l'ordre suivent la base de donnees de reference
/// (BASE DE DONNEES 2eEBC.xlsx).
enum TypeChamp { texte, entier, nombre, date, referentiel, position, section, fonction }

class ChampPersonnel {
  final String libelle;
  final TypeChamp type;

  /// Colonne SQLite a mettre a jour (pour [TypeChamp.texte], `entier`,
  /// `nombre`, `date` et `referentiel`).
  final String? colonne;

  /// Cle de la table de reference (pour le type referentiel).
  final String? tableRef;

  const ChampPersonnel(
    this.libelle,
    this.type, {
    this.colonne,
    this.tableRef,
  });
}

/// Les informations modifiables en masse (ordre du fichier de reference).
const List<ChampPersonnel> kChampsPersonnel = [
  ChampPersonnel('GRADE', TypeChamp.referentiel,
      colonne: 'grade_id', tableRef: 'grades'),
  ChampPersonnel('NOM ET PRENOMS', TypeChamp.texte, colonne: 'nom_prenoms'),
  ChampPersonnel('MATRICULE', TypeChamp.texte, colonne: 'matricule'),
  ChampPersonnel('MECANO', TypeChamp.texte, colonne: 'mecano'),
  ChampPersonnel('ESCADRON', TypeChamp.referentiel,
      colonne: 'escadron_id', tableRef: 'escadrons'),
  ChampPersonnel('PELOTON', TypeChamp.section, tableRef: 'sections'),
  ChampPersonnel('FONCTION', TypeChamp.fonction, tableRef: 'fonctions'),
  ChampPersonnel('POSITION', TypeChamp.position),
  ChampPersonnel('DATE DE NAISSANCE', TypeChamp.date, colonne: 'date_naissance'),
  ChampPersonnel('LIEU DE NAISSANCE', TypeChamp.texte, colonne: 'lieu_naissance'),
  ChampPersonnel('NOM DU PERE', TypeChamp.texte, colonne: 'nom_pere'),
  ChampPersonnel('NOM DE LA MERE', TypeChamp.texte, colonne: 'nom_mere'),
  ChampPersonnel('CATEGORIE', TypeChamp.referentiel,
      colonne: 'categorie_id', tableRef: 'categories'),
  ChampPersonnel('GENRE', TypeChamp.texte, colonne: 'genre'),
  ChampPersonnel('SITUATION MATRIMONIALE', TypeChamp.referentiel,
      colonne: 'situation_matrimoniale_id', tableRef: 'situationsMatrimoniales'),
  ChampPersonnel('DATE DEBUT SERVICE', TypeChamp.date,
      colonne: 'date_debut_service'),
  ChampPersonnel('DATE DE NOMINATION', TypeChamp.date,
      colonne: 'date_nomination'),
  ChampPersonnel('REFERENCE DE NOMINATION', TypeChamp.texte,
      colonne: 'reference_nomination'),
  ChampPersonnel("DATE D'ARRIVEE AU CORPS", TypeChamp.date,
      colonne: 'date_arrivee_corps'),
  ChampPersonnel("DATE D'EFFET", TypeChamp.date, colonne: 'date_effet'),
  ChampPersonnel('UNITE DE PROVENANCE', TypeChamp.texte,
      colonne: 'unite_provenance'),
  ChampPersonnel("REFERENCE D'AFFECTATION", TypeChamp.texte,
      colonne: 'reference_affectation'),
  ChampPersonnel("DATE D'AFFECTATION / RADIATION OU DECES", TypeChamp.date,
      colonne: 'date_affectation'),
  ChampPersonnel("NOUVELLE UNITE D'AFFECTATION / LIEU DE DECES",
      TypeChamp.texte, colonne: 'nouvelle_unite_affectation'),
  ChampPersonnel('REFERENCE', TypeChamp.texte, colonne: 'reference'),
  ChampPersonnel('DOMAINE', TypeChamp.referentiel,
      colonne: 'domaine_id', tableRef: 'domaines'),
  ChampPersonnel('DIPLOME MILITAIRE', TypeChamp.texte,
      colonne: 'diplome_militaire'),
  ChampPersonnel('DECISION', TypeChamp.texte, colonne: 'decision'),
  ChampPersonnel('DIPLOME CIVIL', TypeChamp.texte, colonne: 'diplome_civil'),
  ChampPersonnel("NIVEAU D'ETUDE", TypeChamp.texte, colonne: 'niveau_etude'),
  ChampPersonnel('NOM CONJOINT', TypeChamp.texte, colonne: 'nom_conjoint'),
  ChampPersonnel("NBRE D'ENFANT", TypeChamp.entier, colonne: 'nombre_enfants'),
  ChampPersonnel('PERSONNE A APPELER EN CAS D\'URGENCE', TypeChamp.texte,
      colonne: 'personne_appeler'),
  ChampPersonnel('N° TELEPHONE', TypeChamp.texte, colonne: 'telephone'),
  ChampPersonnel('N° CIM', TypeChamp.texte, colonne: 'numero_cim'),
  ChampPersonnel('CNI', TypeChamp.texte, colonne: 'cni'),
  ChampPersonnel('NNI', TypeChamp.texte, colonne: 'nni'),
  ChampPersonnel('PASSEPORT', TypeChamp.texte, colonne: 'passeport'),
  ChampPersonnel('MUGEFCI', TypeChamp.texte, colonne: 'mugfci'),
  ChampPersonnel('FPM', TypeChamp.texte, colonne: 'fpm'),
  ChampPersonnel('CMU', TypeChamp.texte, colonne: 'cmu'),
  ChampPersonnel('GROUPE SANGUIN', TypeChamp.referentiel,
      colonne: 'groupe_sanguin_id', tableRef: 'groupesSanguins'),
  ChampPersonnel("LIEU D'HABITATION", TypeChamp.texte,
      colonne: 'lieu_habitation'),
  ChampPersonnel('LIVRET MATRICULE', TypeChamp.texte,
      colonne: 'livret_matricule'),
  ChampPersonnel('DOSSIER DE PENSION', TypeChamp.texte,
      colonne: 'dossier_pension'),
  ChampPersonnel('DROIT A DOSSIER DE PENSION', TypeChamp.texte,
      colonne: 'droit_dossier_pension'),
  ChampPersonnel('SITUATION DOSSIER', TypeChamp.texte,
      colonne: 'situation_dossier'),
  ChampPersonnel('PROMOTION OU CLASSE', TypeChamp.texte,
      colonne: 'promotion_classe'),
  ChampPersonnel('TAILLE', TypeChamp.nombre, colonne: 'taille'),
];
