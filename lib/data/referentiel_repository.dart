import 'package:sqflite/sqflite.dart';

import '../models/referentiel.dart';
import 'journal.dart';

/// Acces aux tables de reference.
class ReferentielRepository {
  final Database db;
  ReferentielRepository(this.db);

  Future<List<RefItem>> grades() async {
    final rows = await db.rawQuery('''
SELECT g.id, g.code, g.libelle, g.ordre, c.code AS categorie_code
FROM grade g
LEFT JOIN categorie c ON c.id = g.categorie_id
ORDER BY c.id ASC, g.ordre ASC
''');
    return rows.map(RefItem.fromMap).toList();
  }

  Future<List<RefItem>> categories() async {
    final rows = await db.query('categorie', orderBy: 'id ASC');
    return rows.map(RefItem.fromMap).toList();
  }

  Future<List<StatutItem>> statuts() async {
    final rows = await db.query('statut', orderBy: 'ordre_rapport ASC');
    return rows.map(StatutItem.fromMap).toList();
  }

  Future<List<RefItem>> sections() async {
    final rows = await db.query('section', orderBy: 'ordre ASC');
    return rows.map(RefItem.fromMap).toList();
  }

  Future<List<RefItem>> escadrons() async {
    final rows = await db.query('escadron', orderBy: 'id ASC');
    return rows.map(RefItem.fromMap).toList();
  }

  Future<List<RefItem>> fonctions() async {
    final rows = await db.query('fonction', orderBy: 'id ASC');
    return rows.map(RefItem.fromMap).toList();
  }

  Future<List<RefItem>> typesService() async {
    final rows = await db.query('type_service', orderBy: 'id ASC');
    return rows.map(RefItem.fromMap).toList();
  }

  Future<List<RefItem>> postes() async {
    final rows = await db.query('poste', orderBy: 'id ASC');
    return rows.map(RefItem.fromMap).toList();
  }

  Future<List<RefItem>> typesArme() async {
    // Table optionnelle (armement desactive) : ne pas bloquer le chargement
    // des autres referentiels sur une installation neuve.
    final existe = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = 'type_arme'");
    if (existe.isEmpty) return const [];
    final rows = await db.query('type_arme', orderBy: 'id ASC');
    return rows.map(RefItem.fromMap).toList();
  }

  Future<List<RefItem>> groupesSanguins() async {
    final rows = await db.query('groupe_sanguin', orderBy: 'code ASC');
    return rows.map(RefItem.fromMap).toList();
  }

  Future<List<RefItem>> situationsMatrimoniales() async {
    final rows = await db.query('situation_matrimoniale', orderBy: 'id ASC');
    return rows.map(RefItem.fromMap).toList();
  }

  Future<List<RefItem>> domaines() async {
    final rows = await db.query('domaine', orderBy: 'libelle ASC');
    return rows.map(RefItem.fromMap).toList();
  }

  /// Genere un code a partir d'un libelle (majuscules, sans accents/espace).
  static String _codeDepuis(String libelle) {
    final cleaned = libelle
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (cleaned.isEmpty) return 'ITEM';
    return cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned;
  }

  /// Ajoute un element de referentiel ("Autre a preciser") et retourne son id.
  /// Si un element identique existe deja (meme code), retourne son id.
  Future<int> ajouterItem(
    String table, {
    required String libelle,
    int? escadronId,
  }) async {
    final texte = libelle.trim();
    final code = table == 'groupe_sanguin'
        ? texte.toUpperCase()
        : _codeDepuis(texte);
    final exists = await db.query(table,
        where: table == 'section' && escadronId != null
            ? 'code = ? AND escadron_id = ?'
            : 'code = ?',
        whereArgs: table == 'section' && escadronId != null
            ? [code, escadronId]
            : [code],
        limit: 1);
    if (exists.isNotEmpty) return exists.first['id'] as int? ?? -1;
    final map = <String, Object?>{
      'code': code,
      if (table != 'groupe_sanguin') 'libelle': texte,
      if (table == 'section') 'escadron_id': escadronId,
      if (table == 'section') 'ordre': 999,
    };
    final id = await db.insert(table, map,
        conflictAlgorithm: ConflictAlgorithm.ignore);
    if (id <= 0) return -1;
    await Journal.tracer(db,
        action: 'CREATE', entite: table, entiteId: '$id', apres: map);
    await Journal.enfiler(db,
        entite: table, entiteId: '$id', action: 'CREATE', payload: map);
    return id;
  }

  /// Precisions d'une position : valeurs par defaut + valeurs ajoutees par
  /// l'utilisateur via "AJOUTER".
  Future<List<RefItem>> precisionsPosition(String position) async {
    final rows = await db.query(
      'precision_position',
      where: 'position = ?',
      whereArgs: [position],
      orderBy: 'id ASC',
    );
    return rows
        .map((m) => RefItem(
              id: (m['id'] as int?) ?? 0,
              code: (m['position'] ?? '') as String,
              libelle: (m['libelle'] ?? '') as String,
            ))
        .toList();
  }

  /// Enregistre une nouvelle precision de position (reutilisable ensuite).
  Future<void> ajouterPrecisionPosition({
    required String position,
    required String libelle,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    final now = DateTime.now().toIso8601String();
    final map = {
      'position': position,
      'libelle': libelle,
      'created_at': now,
      'created_by': utilisateurId,
    };
    await db.insert('precision_position', map,
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await Journal.tracer(db,
        action: 'CREATE',
        entite: 'precision_position',
        entiteId: '$position/$libelle',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: map);
    await Journal.enfiler(db,
        entite: 'precision_position',
        entiteId: '$position/$libelle',
        action: 'CREATE',
        payload: map);
  }
}
