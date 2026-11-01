/// Positions standard proposees dans le selecteur : ce sont les rubriques du
/// volet "Repartition du personnel" du tableau de bord.
const List<String> kPositions = [
  'Présent',
  'Mission',
  'Stage',
  'Mise a disposition',
  'Permission',
  'Malade',
  'Repos',
  'Absent',
];

/// Precisions (sous-categories) proposees selon la position choisie.
const Map<String, List<String>> kPositionPrecisions = {
  'Mission': ['LOMO NORD', 'ZON', 'F.E'],
  'Stage': ['INTERNE', 'EXTERNE'],
  'Mise a disposition': ['ORDINAIRE', 'CORVEE EMAT', 'HAITI', 'INTERNE', 'ENSOA'],
  'Permission': ['LONGUE DUREE', 'COURTE DUREE'],
};

/// Precisions disponibles pour une position (vide si la position n'en a pas).
List<String> precisionsPourPosition(String? position) =>
    kPositionPrecisions[(position ?? '').trim()] ?? const <String>[];

/// Libelle d'affichage combinant la position et sa precision.
String libellePosition(String? position, String? precision) {
  final pos = (position ?? '').trim();
  final prec = (precision ?? '').trim();
  return prec.isEmpty ? pos : '$pos - $prec';
}

/// Valeur affichee quand une information de position n'est pas connue.
const String kIndetermine = 'indéterminé';

/// Formate une date/heure de debut ISO en "jj/mm/aaaa hh:mm".
/// Retourne "indéterminé" si la valeur n'est pas renseignee.
String texteDebut(String? iso) {
  final v = (iso ?? '').trim();
  if (v.isEmpty) return 'indéterminé';
  final d = DateTime.tryParse(v);
  if (d == null) return v;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}'
      '/${d.year} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// Duree d'une position ("indéterminé" si non renseignee).
String texteDuree(String? duree) {
  final v = (duree ?? '').trim();
  return v.isEmpty ? 'indéterminé' : v;
}

/// Resume "Debut <...>  |  Duree <...>" pour l'affichage compact.
String resumePosition(String? debut, String? duree) =>
    'Début ${texteDebut(debut)}  •  Durée ${texteDuree(duree)}';

/// Correspondance entre une position (champ texte libre du militaire) et le
/// code de statut utilise par le tableau de bord (table `situation`).
String statutCodeDepuisPosition(String? position) {
  final v = (position ?? '').toUpperCase();
  if (v.contains('REPOS')) return 'REPOS_MEDICAL';
  if (v.contains('MALADE')) return 'MALADE';
  if (v.contains('PERMISSION') || v.contains('CONGE')) return 'EN_PERMISSION';
  if (v.contains('STAGE')) return 'EN_STAGE';
  if (v.contains('MAD') || v.contains('MISE A DISPOSITION')) {
    return 'MISE_A_DISPOSITION';
  }
  if (v.contains('MISSION') || v.contains('OPS')) return 'EN_MISSION';
  if (v.contains('ABSENT')) return 'ABSENT';
  return 'EN_SERVICE';
}

/// Position (rubrique) correspondant a un code de statut.
String positionDepuisStatutCode(String? code) {
  switch (code) {
    case 'EN_MISSION':
      return 'Mission';
    case 'EN_STAGE':
      return 'Stage';
    case 'MISE_A_DISPOSITION':
      return 'Mise a disposition';
    case 'EN_PERMISSION':
    case 'EN_CONGE':
      return 'Permission';
    case 'MALADE':
      return 'Malade';
    case 'REPOS_MEDICAL':
      return 'Repos';
    case 'ABSENT':
      return 'Absent';
    case 'EN_SERVICE':
    default:
      return 'Présent';
  }
}
