import '../core/rbac.dart';

/// Utilisateur de l'application (authentification + RBAC).
class AppUser {
  final int? id;
  final String username;
  final String nomComplet;
  final String roleCode;
  final int? militaireId;

  /// Peloton (section) rattache a un Chef de Peloton (null pour le Commandant).
  final int? sectionId;
  final bool actif;
  final String? derniereConnexion;

  AppUser({
    this.id,
    required this.username,
    required this.nomComplet,
    required this.roleCode,
    this.militaireId,
    this.sectionId,
    this.actif = true,
    this.derniereConnexion,
  });

  factory AppUser.fromMap(Map<String, Object?> m) {
    return AppUser(
      id: m['id'] as int?,
      username: (m['username'] ?? '') as String,
      nomComplet: (m['nom_complet'] ?? '') as String,
      roleCode: (m['role_code'] ?? RoleCode.chefPeloton) as String,
      militaireId: m['militaire_id'] as int?,
      sectionId: m['section_id'] as int?,
      actif: ((m['actif'] as int?) ?? 1) == 1,
      derniereConnexion: m['derniere_connexion'] as String?,
    );
  }

  String get roleLibelle => kRoleLibelles[roleCode] ?? roleCode;

  bool get estCommandantEscadron => roleCode == RoleCode.cmdEscadron;
  bool get estChefPeloton => roleCode == RoleCode.chefPeloton;

  /// Peloton auquel l'acces est restreint (Chef de Peloton), sinon null
  /// (acces a tout l'escadron).
  int? get perimetreSectionId => estChefPeloton ? sectionId : null;

  bool hasPermission(String permission) {
    final perms = kRolePermissions[roleCode] ?? const <String>[];
    return perms.contains(permission);
  }

  bool hasAny(List<String> permissions) =>
      permissions.any((p) => hasPermission(p));
}
