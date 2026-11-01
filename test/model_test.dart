import 'package:flutter_test/flutter_test.dart';
import 'package:gpm_ebc/core/positions.dart';
import 'package:gpm_ebc/core/rbac.dart';
import 'package:gpm_ebc/models/app_user.dart';
import 'package:gpm_ebc/models/personnel.dart';

void main() {
  test('Personnel.fromMap lit les champs et les libelles joints', () {
    final p = Personnel.fromMap({
      'id': 1,
      'nom_prenoms': 'KRAGBA GUY-MARTIN',
      'matricule': 'S/M',
      'grade_libelle': 'Capitaine',
      'statut_disponible': 1,
      'statut_libelle': 'En service',
    });
    expect(p.id, 1);
    expect(p.nomPrenoms, 'KRAGBA GUY-MARTIN');
    expect(p.gradeLibelle, 'Capitaine');
    expect(p.disponible, isTrue);
    expect(p.statutLibelle, 'En service');
  });

  test('RBAC: le Commandant Escadron possede toutes les permissions clefs', () {
    final u = AppUser(
      username: 'admin',
      nomComplet: 'Admin',
      roleCode: RoleCode.cmdEscadron,
    );
    expect(u.hasPermission(Perm.personnelRead), isTrue);
    expect(u.hasPermission(Perm.adminManage), isTrue);
    expect(u.hasPermission(Perm.rapportExport), isTrue);
    expect(u.estCommandantEscadron, isTrue);
    expect(u.perimetreSectionId, isNull);
  });

  test('texteDebut formate l ISO et signale l indetermine', () {
    expect(texteDebut(null), 'indéterminé');
    expect(texteDebut('   '), 'indéterminé');
    expect(texteDebut('2026-10-12T06:05:00.000'), '12/10/2026 06:05');
  });

  test('texteDuree et resumePosition signalent l indetermine', () {
    expect(texteDuree(null), 'indéterminé');
    expect(texteDuree('48h'), '48h');
    expect(resumePosition(null, null), 'Début indéterminé  •  Durée indéterminé');
  });

  test('Personnel lit position_debut et position_duree', () {
    final p = Personnel.fromMap({
      'nom_prenoms': 'TEST',
      'position_debut': '2026-10-12T06:00:00.000',
      'position_duree': '48h',
    });
    expect(p.positionDebut, '2026-10-12T06:00:00.000');
    expect(p.positionDuree, '48h');
  });

  test('RBAC: le Chef de Peloton est restreint a son peloton', () {
    final u = AppUser(
      username: 'chef1',
      nomComplet: 'Chef 1',
      roleCode: RoleCode.chefPeloton,
      sectionId: 3,
    );
    expect(u.hasPermission(Perm.personnelRead), isTrue);
    expect(u.hasPermission(Perm.statutUpdate), isTrue);
    expect(u.hasPermission(Perm.serviceCreate), isTrue);
    expect(u.hasPermission(Perm.rapportExport), isTrue);
    expect(u.hasPermission(Perm.personnelUpdate), isFalse);
    expect(u.hasPermission(Perm.armementMove), isFalse);
    expect(u.hasPermission(Perm.adminManage), isFalse);
    expect(u.estChefPeloton, isTrue);
    expect(u.perimetreSectionId, 3);
  });
}
