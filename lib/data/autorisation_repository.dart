import 'package:sqflite/sqflite.dart';

import 'journal.dart';

/// Depot des autorisations accordees par le Commandant Escadron aux chefs
/// de peloton (modification des donnees de leur peloton).
class AutorisationRepository {
  final Database db;
  AutorisationRepository(this.db);

  /// Toutes les autorisations : section_id -> code -> accorde.
  Future<Map<int, Map<String, bool>>> toutes() async {
    final rows = await db.query('autorisation');
    final res = <int, Map<String, bool>>{};
    for (final r in rows) {
      final sectionId = r['section_id'] as int?;
      final code = r['code'] as String?;
      if (sectionId == null || code == null) continue;
      (res[sectionId] ??= {})[code] = ((r['accorde'] as int?) ?? 0) == 1;
    }
    return res;
  }

  /// Autorisations d'un peloton : code -> accorde (absent = non accordee).
  Future<Map<String, bool>> pourSection(int sectionId) async {
    final rows = await db.query('autorisation',
        where: 'section_id = ?', whereArgs: [sectionId]);
    return {
      for (final r in rows)
        (r['code'] as String): ((r['accorde'] as int?) ?? 0) == 1,
    };
  }

  Future<bool> estAccordee(int sectionId, String code) async {
    final rows = await db.query('autorisation',
        where: 'section_id = ? AND code = ?',
        whereArgs: [sectionId, code],
        limit: 1);
    if (rows.isEmpty) return false;
    return ((rows.first['accorde'] as int?) ?? 0) == 1;
  }

  /// Accorde ou retire une autorisation a un peloton.
  Future<void> definir({
    required int sectionId,
    required String code,
    required bool accorde,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    final maintenant = DateTime.now().toIso8601String();
    final existant = await db.query('autorisation',
        where: 'section_id = ? AND code = ?',
        whereArgs: [sectionId, code],
        limit: 1);
    final valeurs = {
      'accorde': accorde ? 1 : 0,
      'maj_par': utilisateurId,
      'maj_le': maintenant,
    };
    if (existant.isEmpty) {
      await db.insert('autorisation', {
        'section_id': sectionId,
        'code': code,
        ...valeurs,
      });
    } else {
      await db.update('autorisation', valeurs,
          where: 'section_id = ? AND code = ?',
          whereArgs: [sectionId, code]);
    }
    await Journal.tracer(db,
        action: 'AUTORISATION',
        entite: 'autorisation',
        entiteId: '$sectionId/$code',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: {'accorde': accorde});
  }
}
