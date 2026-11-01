/// Autorisations qu'un Chef de Peloton doit obtenir du Commandant Escadron
/// pour modifier les donnees de son peloton.
class AutorisationCode {
  AutorisationCode._();

  /// Modifier le statut et la position des militaires.
  static const String statut = 'modifier_statut';

  /// Creer, modifier et supprimer les services.
  static const String service = 'modifier_service';
}

/// Description d'une autorisation accordable a un peloton.
class AutorisationDef {
  final String code;
  final String libelle;
  final String description;
  const AutorisationDef(this.code, this.libelle, this.description);
}

/// Autorisations disponibles (par defaut : non accordees).
const List<AutorisationDef> kAutorisations = [
  AutorisationDef(
    AutorisationCode.statut,
    'Statuts et positions',
    'Modifier le statut et la position des militaires du peloton',
  ),
  AutorisationDef(
    AutorisationCode.service,
    'Services',
    'Creer, modifier et supprimer les services du peloton',
  ),
];

AutorisationDef? autorisationParCode(String code) {
  for (final a in kAutorisations) {
    if (a.code == code) return a;
  }
  return null;
}
