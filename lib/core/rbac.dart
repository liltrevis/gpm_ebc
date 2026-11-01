/// Codes de roles. L'application distingue deux types d'utilisateurs :
/// le Commandant d'Escadron et les Chefs de Peloton.
class RoleCode {
  static const String cmdEscadron = 'CMD_ESC';
  static const String chefPeloton = 'CHEF_PEL';
}

/// Le role correspond-il a un chef de peloton (perimetre restreint a son
/// peloton) ?
bool estRoleChefPeloton(String? roleCode) => roleCode == RoleCode.chefPeloton;

/// Codes de permissions (RBAC).
class Perm {
  static const String personnelRead = 'personnel.read';
  static const String personnelCreate = 'personnel.create';
  static const String personnelUpdate = 'personnel.update';
  static const String personnelDelete = 'personnel.delete';
  static const String statutUpdate = 'statut.update';
  static const String serviceRead = 'service.read';
  static const String serviceCreate = 'service.create';
  static const String serviceValidate = 'service.validate';
  // Armement desactive pour le moment
  static const String armementRead = 'armement.read.disabled';
  static const String armementMove = 'armement.move.disabled';
  static const String armementValidate = 'armement.validate.disabled';
  static const String rapportRead = 'rapport.read';
  static const String rapportCreate = 'rapport.create';
  static const String rapportExport = 'rapport.export';
  static const String auditRead = 'audit.read';
  static const String adminManage = 'admin.manage';
}

/// Matrice role -> permissions.
const Map<String, List<String>> kRolePermissions = {
  // Commandant d'Escadron : acces complet (dont gestion des comptes).
  RoleCode.cmdEscadron: [
    Perm.personnelRead, Perm.personnelCreate, Perm.personnelUpdate, Perm.personnelDelete,
    Perm.statutUpdate, Perm.serviceRead, Perm.serviceCreate, Perm.serviceValidate,
    Perm.rapportRead, Perm.rapportCreate, Perm.rapportExport,
    Perm.auditRead, Perm.adminManage,
  ],
  // Chef de Peloton : lecture, mise a jour des statuts, creation/gestion
  // de services pour son peloton, et exports de documents de son peloton.
  RoleCode.chefPeloton: [
    Perm.personnelRead, Perm.statutUpdate,
    Perm.serviceRead, Perm.serviceCreate,
    Perm.rapportRead, Perm.rapportExport,
  ],
};

/// Libelles des roles.
const Map<String, String> kRoleLibelles = {
  RoleCode.cmdEscadron: 'Commandant Escadron',
  RoleCode.chefPeloton: 'Chef de Peloton',
};
