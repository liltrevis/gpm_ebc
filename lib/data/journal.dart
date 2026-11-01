import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

/// Journal d'audit (chaine de hachage) et file d'attente de synchronisation.
class Journal {
  static Future<void> tracer(
    Database db, {
    required String action,
    required String entite,
    String? entiteId,
    int? utilisateurId,
    String? utilisateurNom,
    Map<String, Object?>? avant,
    Map<String, Object?>? apres,
  }) async {
    final last = await db.query(
      'journal_audit',
      columns: ['hash_courant'],
      orderBy: 'id DESC',
      limit: 1,
    );
    final prev = last.isEmpty ? '' : ((last.first['hash_courant'] ?? '') as String);
    final now = DateTime.now().toIso8601String();
    final charge = '$prev|$action|$entite|${entiteId ?? ''}|$now|'
        '${jsonEncode(avant)}|${jsonEncode(apres)}';
    final hash = sha256.convert(utf8.encode(charge)).toString();
    await db.insert('journal_audit', {
      'utilisateur_id': utilisateurId,
      'utilisateur_nom': utilisateurNom,
      'action': action,
      'entite': entite,
      'entite_id': entiteId,
      'valeur_avant': avant == null ? null : jsonEncode(avant),
      'valeur_apres': apres == null ? null : jsonEncode(apres),
      'date_heure': now,
      'hash_precedent': prev,
      'hash_courant': hash,
    });
  }

  static Future<void> enfiler(
    Database db, {
    required String entite,
    String? entiteId,
    required String action,
    Map<String, Object?>? payload,
  }) async {
    await db.insert('sync_outbox', {
      'entite': entite,
      'entite_id': entiteId,
      'action': action,
      'payload': payload == null ? null : jsonEncode(payload),
      'date_heure': DateTime.now().toIso8601String(),
      'synchronise': 0,
    });
  }

  static Future<int> enAttente(Database db) async {
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM sync_outbox WHERE synchronise = 0',
    );
    return (r.first['n'] as int?) ?? 0;
  }
}
