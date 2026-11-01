import 'package:sqflite/sqflite.dart';

import '../models/arme.dart';
import 'journal.dart';

/// Depot d'acces au parc d'armement (armes, munitions, mouvements).
class ArmementRepository {
  final Database db;
  ArmementRepository(this.db);

  Future<List<Arme>> armes({String? recherche, String? etat}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (recherche != null && recherche.trim().isNotEmpty) {
      final r = '%${recherche.trim()}%';
      where.add('(a.numero_serie LIKE ? OR ta.libelle LIKE ?)');
      args.addAll([r, r]);
    }
    if (etat != null) {
      where.add('a.etat = ?');
      args.add(etat);
    }
    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery('''
SELECT a.*, ta.libelle AS type_libelle, ta.calibre AS calibre
FROM arme a
LEFT JOIN type_arme ta ON ta.id = a.type_arme_id
$clause
ORDER BY ta.code ASC, a.numero_serie ASC
''', args);
    return rows.map(Arme.fromMap).toList();
  }

  Future<List<Munition>> munitions() async {
    final rows = await db.query('munition', orderBy: 'type_calibre ASC');
    return rows.map(Munition.fromMap).toList();
  }

  Future<List<Mouvement>> mouvements({int limite = 50}) async {
    final rows = await db.rawQuery('''
SELECT m.*, a.numero_serie AS arme_numero, mu.designation AS munition_designation,
       p.nom_prenoms AS beneficiaire_nom
FROM mouvement_armurerie m
LEFT JOIN arme a ON a.id = m.arme_id
LEFT JOIN munition mu ON mu.id = m.munition_id
LEFT JOIN personnel p ON p.id = m.beneficiaire_id
ORDER BY m.date_heure DESC LIMIT ?
''', [limite]);
    return rows.map(Mouvement.fromMap).toList();
  }

  Future<int> enregistrerMouvement(
    Mouvement m, {
    String? etatRetour,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    final map = m.toMap();
    final id = await db.insert('mouvement_armurerie', map);

    if (m.sens == 'ENTREE' && m.armeId != null) {
      await db.update(
        'arme',
        {'etat': 'EN_SERVICE', 'localisation': 'Arsenal', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [m.armeId],
      );
      await db.update('dotation', {'date_retour': m.dateHeure, 'etat_retour': etatRetour ?? 'BON'},
          where: 'arme_id = ? AND date_retour IS NULL', whereArgs: [m.armeId]);
    }
    if (m.sens == 'SORTIE' && m.armeId != null) {
      await db.update('arme', {'localisation': 'DOTEE', 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?', whereArgs: [m.armeId]);
      await db.insert('dotation', {
        'militaire_id': m.beneficiaireId,
        'arme_id': m.armeId,
        'date_dotation': m.dateHeure,
        'type_usage': m.motif,
        'etat_depart': 'BON',
        'created_by': utilisateurId,
      });
    }
    if (m.munitionId != null && m.quantite > 0) {
      final delta = m.sens == 'SORTIE' ? -m.quantite : m.quantite;
      await db.rawUpdate(
        'UPDATE munition SET stock_actuel = stock_actuel + ? WHERE id = ?',
        [delta, m.munitionId],
      );
    }

    await Journal.tracer(db,
        action: 'MOUVEMENT_${m.sens}',
        entite: 'armement',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: map);
    await Journal.enfiler(db,
        entite: 'armement', entiteId: '$id', action: 'MOUVEMENT_${m.sens}', payload: map);
    return id;
  }

  Future<int> armesDotees() async {
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM dotation WHERE date_retour IS NULL');
    return (r.first['n'] as int?) ?? 0;
  }
}
