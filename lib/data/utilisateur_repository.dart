import 'package:sqflite/sqflite.dart';

import '../models/app_user.dart';
import 'database.dart';

/// Depot utilisateurs (authentification + gestion des comptes).
class UtilisateurRepository {
  final Database db;
  UtilisateurRepository(this.db);

  Future<AppUser?> authentifier(String username, String motDePasse) async {
    final rows = await db.query(
      'utilisateur',
      where: 'username = ? AND actif = 1',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final stored = rows.first['mot_de_passe_hash'] as String?;
    if (stored != hasherMotDePasse(motDePasse)) return null;
    await db.update(
      'utilisateur',
      {'derniere_connexion': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
    return AppUser.fromMap(rows.first);
  }

  Future<List<AppUser>> lister() async {
    final rows = await db.query('utilisateur', orderBy: 'id ASC');
    return rows.map(AppUser.fromMap).toList();
  }

  /// Met a jour le type d'utilisateur et, pour un Chef de Peloton, son peloton.
  Future<void> modifierRoleEtSection(
    int id, {
    required String roleCode,
    int? sectionId,
  }) async {
    await db.update(
      'utilisateur',
      {'role_code': roleCode, 'section_id': sectionId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> creer({
    required String username,
    required String nomComplet,
    required String motDePasse,
    required String roleCode,
    int? militaireId,
    int? sectionId,
  }) async {
    return db.insert('utilisateur', {
      'username': username,
      'nom_complet': nomComplet,
      'mot_de_passe_hash': hasherMotDePasse(motDePasse),
      'role_code': roleCode,
      'militaire_id': militaireId,
      'section_id': sectionId,
      'actif': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> basculerActif(int id, bool actif) async {
    await db.update('utilisateur', {'actif': actif ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
