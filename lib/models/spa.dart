/// Nature d'une ligne du document SPA (Situation des Personnels Absents).
enum SpaType { effectif, rubrique, sousRubrique, total }

/// Ligne du tableau SPA : libelle + effectifs par categorie statutaire.
class SpaRow {
  final String libelle;
  final int officiers;
  final int sousOfficiers;
  final int hommesDuRang;
  final SpaType type;

  /// Observation nominative (grades + noms) associee a la ligne.
  final String observation;

  const SpaRow({
    required this.libelle,
    this.officiers = 0,
    this.sousOfficiers = 0,
    this.hommesDuRang = 0,
    this.type = SpaType.rubrique,
    this.observation = '',
  });

  int get total => officiers + sousOfficiers + hommesDuRang;
}

/// Document SPA complet pret a etre exporte (PDF / Excel / Word).
class SpaData {
  final String unite;
  final String dateSituation;
  final List<SpaRow> rows;

  const SpaData({
    required this.unite,
    required this.dateSituation,
    required this.rows,
  });

  /// Regroupe les lignes en blocs : chaque position principale suit ses
  /// precisions (sous-rubriques), qui sont ainsi imbriquees dans la position.
  List<SpaBloc> get blocs => grouperBlocs(rows);
}

/// Regroupe une liste de lignes SPA en blocs (position + ses precisions).
List<SpaBloc> grouperBlocs(List<SpaRow> rows) {
  final resultat = <SpaBloc>[];
  for (final r in rows) {
    if (r.type == SpaType.sousRubrique && resultat.isNotEmpty) {
      resultat.last.precisions.add(r);
    } else {
      resultat.add(SpaBloc._(r));
    }
  }
  return resultat;
}

/// Bloc du tableau SPA : une ligne principale et ses lignes de precision.
class SpaBloc {
  final SpaRow ligne;
  final List<SpaRow> precisions;

  SpaBloc._(this.ligne) : precisions = [];

  bool get aDesPrecisions => precisions.isNotEmpty;

  /// Nombre de lignes de texte du bloc (position + precisions).
  int get hauteur => 1 + precisions.length;

  /// Valeurs d'une colonne, une par ligne : la position puis ses precisions.
  List<String> valeursColonne(String Function(SpaRow) valeur) => [
        valeur(ligne),
        for (final p in precisions) valeur(p),
      ];
}
