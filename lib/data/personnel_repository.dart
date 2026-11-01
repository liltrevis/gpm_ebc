import 'package:sqflite/sqflite.dart';

import '../core/positions.dart';
import '../models/personnel.dart';
import 'journal.dart';

/// Depot d'acces aux militaires.
class PersonnelRepository {
  final Database db;
  PersonnelRepository(this.db);

  static const String _select = '''
SELECT p.*,
       g.code AS grade_code, g.libelle AS grade_libelle,
       c.libelle AS categorie_libelle,
       ao.section_id AS section_id, ao.fonction_id AS fonction_id,
       sec.libelle AS section_libelle, f.libelle AS fonction_libelle,
       st.id AS statut_id, st.code AS statut_code, st.libelle AS statut_libelle,
       st.disponible AS statut_disponible,
       esc.code AS escadron_code, esc.libelle AS escadron_libelle,
       sm.libelle AS situation_matrimoniale_libelle,
       d.libelle AS domaine_libelle,
       gs.code AS groupe_sanguin_code
FROM personnel p
LEFT JOIN grade g ON g.id = p.grade_id
LEFT JOIN categorie c ON c.id = p.categorie_id
LEFT JOIN escadron esc ON esc.id = p.escadron_id
LEFT JOIN situation_matrimoniale sm ON sm.id = p.situation_matrimoniale_id
LEFT JOIN domaine d ON d.id = p.domaine_id
LEFT JOIN groupe_sanguin gs ON gs.id = p.groupe_sanguin_id
LEFT JOIN affectation_organique ao ON ao.militaire_id = p.id AND ao.actif = 1
LEFT JOIN section sec ON sec.id = ao.section_id
LEFT JOIN fonction f ON f.id = ao.fonction_id
LEFT JOIN statut st ON st.id = (
  SELECT s.statut_id FROM situation s
  WHERE s.militaire_id = p.id
  ORDER BY s.date_debut DESC, s.id DESC LIMIT 1
)
''';

  Future<List<Personnel>> lister({
    String? recherche,
    int? sectionId,
    List<String>? statutCodes,
    bool? disponible,
    int limite = 300,
    int offset = 0,
  }) async {
    final where = <String>['p.actif = 1'];
    final args = <Object?>[];
    if (recherche != null && recherche.trim().isNotEmpty) {
      final r = '%${recherche.trim()}%';
      where.add('(p.nom_prenoms LIKE ? OR p.matricule LIKE ? OR p.mecano LIKE ? OR g.code LIKE ?)');
      args.addAll([r, r, r, r]);
    }
    if (sectionId != null) {
      where.add('ao.section_id = ?');
      args.add(sectionId);
    }
    if (statutCodes != null && statutCodes.isNotEmpty) {
      final ph = List.filled(statutCodes.length, '?').join(', ');
      where.add('st.code IN ($ph)');
      args.addAll(statutCodes);
    }
    if (disponible != null) {
      where.add('st.disponible = ?');
      args.add(disponible ? 1 : 0);
    }
    final sql = '$_select WHERE ${where.join(' AND ')} '
        'ORDER BY (g.ordre / 100) ASC, g.ordre DESC, p.nom_prenoms ASC LIMIT ? OFFSET ?';
    args.addAll([limite, offset]);
    final rows = await db.rawQuery(sql, args);
    return rows.map(Personnel.fromMap).toList();
  }

  Future<Personnel?> parId(int id) async {
    final rows = await db.rawQuery('$_select WHERE p.id = ?', [id]);
    if (rows.isEmpty) return null;
    return Personnel.fromMap(rows.first);
  }

  Future<List<Personnel>> disponibles({int limite = 400}) async {
    final rows = await db.rawQuery(
      '$_select WHERE p.actif = 1 AND st.disponible = 1 '
      'ORDER BY (g.ordre / 100) ASC, g.ordre DESC, p.nom_prenoms ASC LIMIT ?',
      [limite],
    );
    return rows.map(Personnel.fromMap).toList();
  }

  Future<int> creer(
    Personnel p, {
    int? sectionId,
    int? fonctionId,
    int? statutId,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    final now = DateTime.now().toIso8601String();
    final map = p.toMap();
    map['created_at'] = now;
    map['updated_at'] = now;
    map['created_by'] = utilisateurId;
    map['updated_by'] = utilisateurId;
    final id = await db.insert('personnel', map);
    if (sectionId != null || fonctionId != null) {
      await db.insert('affectation_organique', {
        'militaire_id': id,
        'section_id': sectionId,
        'fonction_id': fonctionId,
        'date_debut': now,
        'actif': 1,
      });
    }
    if (statutId != null) {
      await db.insert('situation', {
        'militaire_id': id,
        'statut_id': statutId,
        'date_debut': now,
        'created_at': now,
        'created_by': utilisateurId,
      });
    }
    await Journal.tracer(db,
        action: 'CREATE',
        entite: 'personnel',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: map);
    await Journal.enfiler(db,
        entite: 'personnel', entiteId: '$id', action: 'CREATE', payload: map);
    return id;
  }

  Future<void> modifier(
    Personnel p, {
    int? sectionId,
    int? fonctionId,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    if (p.id == null) return;
    final now = DateTime.now().toIso8601String();
    final avant = await parId(p.id!);
    final map = p.toMap();
    map.remove('id');
    map['updated_at'] = now;
    map['updated_by'] = utilisateurId;
    await db.update('personnel', map, where: 'id = ?', whereArgs: [p.id]);
    if (sectionId != null || fonctionId != null) {
      await db.update('affectation_organique', {'actif': 0},
          where: 'militaire_id = ? AND actif = 1', whereArgs: [p.id]);
      await db.insert('affectation_organique', {
        'militaire_id': p.id,
        'section_id': sectionId,
        'fonction_id': fonctionId,
        'date_debut': now,
        'actif': 1,
      });
    }
    await Journal.tracer(db,
        action: 'UPDATE',
        entite: 'personnel',
        entiteId: '${p.id}',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        avant: avant?.toMap(),
        apres: map);
    await Journal.enfiler(db,
        entite: 'personnel',
        entiteId: '${p.id}',
        action: 'UPDATE',
        payload: map);
  }

  Future<void> changerStatut({
    required int militaireId,
    required int statutId,
    String? motif,
    String? lieu,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.update('situation', {'date_fin': now},
        where: 'militaire_id = ? AND date_fin IS NULL', whereArgs: [militaireId]);
    await db.insert('situation', {
      'militaire_id': militaireId,
      'statut_id': statutId,
      'date_debut': now,
      'motif': motif,
      'lieu': lieu,
      'created_at': now,
      'created_by': utilisateurId,
    });
    await Journal.tracer(db,
        action: 'CHANGE_STATUT',
        entite: 'personnel',
        entiteId: '$militaireId',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: {'statut_id': statutId, 'motif': motif, 'lieu': lieu});
    await Journal.enfiler(db,
        entite: 'personnel',
        entiteId: '$militaireId',
        action: 'CHANGE_STATUT',
        payload: {'statut_id': statutId});
  }

  /// Modifie la position d'un militaire et re-percute le changement sur son
  /// statut (source des rubriques du tableau de bord).
  Future<void> changerPosition({
    required int militaireId,
    required String? position,
    String? precision,
    String? debut,
    String? duree,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    final now = DateTime.now().toIso8601String();
    final avant = await parId(militaireId);
    final debutEffectif = (debut ?? '').trim();
    await db.update(
      'personnel',
      {
        'position': position,
        'position_precision': precision,
        'position_debut': debutEffectif.isEmpty ? null : debutEffectif,
        'position_duree': (duree ?? '').trim().isEmpty ? null : duree!.trim(),
        'updated_at': now,
        'updated_by': utilisateurId,
      },
      where: 'id = ?',
      whereArgs: [militaireId],
    );

    // Recalcule le statut associe a la nouvelle position.
    final code = statutCodeDepuisPosition(position);
    final rows = await db.query('statut',
        columns: ['id'], where: 'code = ?', whereArgs: [code], limit: 1);
    if (rows.isNotEmpty) {
      final statutId = rows.first['id'] as int;
      final courant = await db.rawQuery(
        'SELECT statut_id FROM situation WHERE militaire_id = ? '
        'ORDER BY date_debut DESC, id DESC LIMIT 1',
        [militaireId],
      );
      final courantId =
          courant.isEmpty ? null : courant.first['statut_id'] as int?;
      if (courantId != statutId) {
        await db.update('situation', {'date_fin': now},
            where: 'militaire_id = ? AND date_fin IS NULL',
            whereArgs: [militaireId]);
        await db.insert('situation', {
          'militaire_id': militaireId,
          'statut_id': statutId,
          'date_debut': debutEffectif.isEmpty ? now : debutEffectif,
          'motif': 'Position : ${position ?? ''}',
          'created_at': now,
          'created_by': utilisateurId,
        });
      }
    }

    await Journal.tracer(db,
        action: 'CHANGE_POSITION',
        entite: 'personnel',
        entiteId: '$militaireId',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        avant: {'position': avant?.position},
        apres: {'position': position, 'precision': precision, 'statut': code});
    await Journal.enfiler(db,
        entite: 'personnel',
        entiteId: '$militaireId',
        action: 'CHANGE_POSITION',
        payload: {'position': position, 'precision': precision, 'statut': code});
  }

  /// Met a jour une colonne (au choix) pour un groupe de militaires.
  Future<int> mettreAJourChamp({
    required List<int> ids,
    required String colonne,
    Object? valeur,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    if (ids.isEmpty) return 0;
    final now = DateTime.now().toIso8601String();
    final ph = List.filled(ids.length, '?').join(', ');
    final map = <String, Object?>{
      colonne: valeur,
      'updated_at': now,
      'updated_by': utilisateurId,
    };
    final n = await db.update('personnel', map,
        where: 'id IN ($ph)', whereArgs: ids);
    final trace = {'colonne': colonne, 'valeur': valeur, 'nombre': n};
    await Journal.tracer(db,
        action: 'UPDATE_GROUPE',
        entite: 'personnel',
        entiteId: colonne,
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: trace);
    await Journal.enfiler(db,
        entite: 'personnel',
        entiteId: colonne,
        action: 'UPDATE_GROUPE',
        payload: {'colonne': colonne, 'ids': ids});
    return n;
  }

  /// Met a jour l'affectation organique (peloton et/ou fonction) d'un groupe.
  Future<int> mettreAJourAffectation({
    required List<int> ids,
    bool setSection = false,
    int? sectionId,
    bool setFonction = false,
    int? fonctionId,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    if (ids.isEmpty) return 0;
    final now = DateTime.now().toIso8601String();
    var n = 0;
    for (final id in ids) {
      final rows = await db.query('affectation_organique',
          where: 'militaire_id = ? AND actif = 1', whereArgs: [id], limit: 1);
      if (rows.isEmpty) {
        await db.insert('affectation_organique', {
          'militaire_id': id,
          if (setSection) 'section_id': sectionId,
          if (setFonction) 'fonction_id': fonctionId,
          'date_debut': now,
          'actif': 1,
        });
      } else {
        final map = <String, Object?>{};
        if (setSection) map['section_id'] = sectionId;
        if (setFonction) map['fonction_id'] = fonctionId;
        if (map.isNotEmpty) {
          await db.update('affectation_organique', map,
              where: 'id = ?', whereArgs: [rows.first['id']]);
        }
      }
      n++;
    }
    final trace = {
      'section_id': setSection ? sectionId : null,
      'fonction_id': setFonction ? fonctionId : null,
      'nombre': n,
    };
    await Journal.tracer(db,
        action: 'UPDATE_GROUPE_AFFECTATION',
        entite: 'personnel',
        entiteId: setSection ? 'peloton' : 'fonction',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: trace);
    await Journal.enfiler(db,
        entite: 'personnel',
        entiteId: 'affectation',
        action: 'UPDATE_GROUPE_AFFECTATION',
        payload: trace);
    return n;
  }

  Future<void> archiver(int id, {int? utilisateurId, String? utilisateurNom}) async {
    await db.update('personnel', {'actif': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
    await Journal.tracer(db,
        action: 'ARCHIVE',
        entite: 'personnel',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom);
    await Journal.enfiler(db,
        entite: 'personnel', entiteId: '$id', action: 'ARCHIVE');
  }
}
