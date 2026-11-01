import 'package:sqflite/sqflite.dart';

import '../models/service.dart';
import 'journal.dart';

/// Depot d'acces aux services et aux affectations de service.
class ServiceRepository {
  final Database db;
  ServiceRepository(this.db);
  static const String _select = '''
SELECT sv.*,
       ts.code AS type_code, ts.libelle AS type_libelle,
       po.libelle AS poste_libelle
FROM service sv
LEFT JOIN type_service ts ON ts.id = sv.type_service_id
LEFT JOIN poste po ON po.id = sv.poste_id
''';
  Future<List<ServiceModel>> lister({
    String? date,
    int limite = 100,
    int? sectionId,
    int? createdBy,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (date != null) {
      where.add('sv.date = ?');
      args.add(date);
    }
    // Perimetre d'un chef de peloton : services concernant son peloton ou
    // crees par lui-meme. Sans perimetre (commandant), aucun filtre.
    if (sectionId != null) {
      where.add('(sv.id IN ('
          'SELECT DISTINCT sa.service_id FROM service_affectation sa '
          'JOIN personnel p ON p.id = sa.militaire_id '
          'JOIN affectation_organique ao '
          'ON ao.militaire_id = p.id AND ao.actif = 1 '
          'WHERE ao.section_id = ?'
          ') OR sv.created_by = ?)');
      args.add(sectionId);
      args.add(createdBy);
    }
    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery(
      '$_select $clause ORDER BY sv.date DESC, sv.creneau_debut ASC LIMIT ?',
      [...args, limite],
    );
    final services = <ServiceModel>[];
    for (final r in rows) {
      final s = ServiceModel.fromMap(r);
      s.affectations = await affectations(s.id!);
      services.add(s);
    }
    return services;
  }

  Future<ServiceModel?> parId(int id) async {
    final rows = await db.rawQuery('$_select WHERE sv.id = ?', [id]);
    if (rows.isEmpty) return null;
    final s = ServiceModel.fromMap(rows.first);
    s.affectations = await affectations(id);
    return s;
  }

  Future<List<AffectationService>> affectations(int serviceId) async {
    final rows = await db.rawQuery('''
SELECT sa.*, p.nom_prenoms AS militaire_nom,
       g.code AS grade_code, g.libelle AS grade_libelle
FROM service_affectation sa
LEFT JOIN personnel p ON p.id = sa.militaire_id
LEFT JOIN grade g ON g.id = p.grade_id
WHERE sa.service_id = ?
ORDER BY sa.role_service ASC, (g.ordre / 100) ASC, g.ordre DESC, p.nom_prenoms ASC
''', [serviceId]);
    return rows.map(AffectationService.fromMap).toList();
  }

  Future<int> creer(
    ServiceModel service, {
    required List<AffectationService> affectations,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    final now = DateTime.now().toIso8601String();
    final map = service.toMap();
    map.remove('id');
    map['created_at'] = now;
    map['created_by'] = utilisateurId;
    final id = await db.insert('service', map);
    for (final a in affectations) {
      await db.insert('service_affectation', {
        'service_id': id,
        'militaire_id': a.militaireId,
        'role_service': a.roleService,
        'present': a.present ? 1 : 0,
        'observation': a.observation,
      });
    }
    await Journal.tracer(db,
        action: 'CREATE',
        entite: 'service',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: map);
    await Journal.enfiler(db,
        entite: 'service', entiteId: '$id', action: 'CREATE', payload: map);
    return id;
  }

  Future<void> valider(int id, {int? utilisateurId, String? utilisateurNom}) async {
    await db.update('service', {'statut': 'VALIDE'}, where: 'id = ?', whereArgs: [id]);
    await Journal.tracer(db,
        action: 'VALIDATE',
        entite: 'service',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom);
    await Journal.enfiler(db,
        entite: 'service', entiteId: '$id', action: 'VALIDATE');
  }

  /// Modifie les informations d'un service existant.
  Future<void> modifier(
    ServiceModel service, {
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    final id = service.id;
    if (id == null) return;
    final map = <String, Object?>{
      'date': service.date,
      'creneau_debut': service.creneauDebut,
      'creneau_fin': service.creneauFin,
      'duree_heures': service.dureeHeures,
      'date_fin': service.dateFin,
      'type_service_id': service.typeServiceId,
      'libelle': service.libelle,
      'poste_id': service.posteId,
      'statut': service.statut,
      'origine': service.origine,
    };
    await db.update('service', map, where: 'id = ?', whereArgs: [id]);
    await Journal.tracer(db,
        action: 'UPDATE',
        entite: 'service',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: map);
    await Journal.enfiler(db,
        entite: 'service', entiteId: '$id', action: 'UPDATE', payload: map);
  }

  /// Supprime un service et tout ce qui lui est rattache (affectations, postes,
  /// roles, grades autorises).
  Future<void> supprimer(int id, {int? utilisateurId, String? utilisateurNom}) async {
    for (final table in const [
      'service_affectation',
      'service_poste',
      'service_role',
      'service_grade_autorise',
    ]) {
      await db.delete(table, where: 'service_id = ?', whereArgs: [id]);
    }
    await db.delete('service_qrf_membre',
        where: 'qrf_id IN (SELECT id FROM service_qrf WHERE service_id = ?)',
        whereArgs: [id]);
    await db.delete('service_qrf', where: 'service_id = ?', whereArgs: [id]);
    await db.delete('service', where: 'id = ?', whereArgs: [id]);
    await Journal.tracer(db,
        action: 'DELETE',
        entite: 'service',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom);
    await Journal.enfiler(db,
        entite: 'service', entiteId: '$id', action: 'DELETE');
  }

  Future<void> marquerPresence(int affectationId, bool present) async {
    await db.update('service_affectation', {'present': present ? 1 : 0},
        where: 'id = ?', whereArgs: [affectationId]);
  }

  /// Genere un service equilibre (equite : moins de services recents d'abord).
  Future<List<AffectationService>> selectionEquitable({
    required String date,
    required int effectif,
    int? sectionId,
  }) async {
    final filtre = sectionId == null
        ? ''
        : ' AND p.id IN (SELECT ao.militaire_id FROM affectation_organique ao '
            'WHERE ao.actif = 1 AND ao.section_id = ?)';
    final rows = await db.rawQuery('''
SELECT p.id AS militaire_id, p.nom_prenoms AS militaire_nom,
  g.libelle AS grade_libelle, g.code AS grade_code,
  (SELECT COUNT(*) FROM service_affectation sa2 WHERE sa2.militaire_id = p.id) AS nb
FROM personnel p
JOIN situation s ON s.militaire_id = p.id AND s.date_fin IS NULL
JOIN statut st ON st.id = s.statut_id
LEFT JOIN grade g ON g.id = p.grade_id
WHERE p.actif = 1 AND st.disponible = 1$filtre
  AND p.id NOT IN (
    SELECT sa3.militaire_id FROM service_affectation sa3
    JOIN service sv2 ON sv2.id = sa3.service_id WHERE sv2.date = ?)
ORDER BY nb ASC, (g.ordre / 100) ASC, g.ordre DESC, p.nom_prenoms ASC
LIMIT ?
''', [if (sectionId != null) sectionId, date, effectif]);
    final liste = <AffectationService>[];
    var i = 0;
    for (final r in rows) {
      liste.add(AffectationService(
        militaireId: r['militaire_id'] as int?,
        militaireNom: r['militaire_nom'] as String?,
        gradeLibelle: r['grade_libelle'] as String?,
        gradeCode: r['grade_code'] as String?,
        roleService: i == 0 ? 'CHEF_POSTE' : 'SENTINELLE',
      ));
      i++;
    }
    return liste;
  }

  // ---------------------------------------------------------------------------
  // Postes d'un service (principal >> postes basiques + chef/adjoint).
  // ---------------------------------------------------------------------------
  Future<List<ServicePoste>> postes(int serviceId) async {
    final rows = await db.query('service_poste',
        where: 'service_id = ?',
        whereArgs: [serviceId],
        orderBy: 'ordre ASC, id ASC');
    final liste = rows.map(ServicePoste.fromMap).toList();
    for (final p in liste) {
      p.affectations = await _affectationsPoste(p.id!);
      p.gradesAutorises = await _gradesPoste(p.id!);
    }
    return liste;
  }

  /// Grades autorises d'un poste, indexes par responsabilite (chef, adjoint,
  /// faction).
  Future<Map<String, Set<int>>> _gradesPoste(int posteId) async {
    final rows = await db.query(
      'service_grade_autorise',
      where: 'cible_id = ? AND cible_type IN (?, ?, ?)',
      whereArgs: [posteId, CibleGrade.chef, CibleGrade.adjoint, CibleGrade.faction],
    );
    final map = <String, Set<int>>{};
    for (final r in rows) {
      final type = r['cible_type'] as String;
      (map[type] ??= <int>{}).add(r['grade_id'] as int);
    }
    return map;
  }

  Future<List<AffectationService>> _affectationsPoste(int posteId) async {
    final rows = await db.rawQuery('''
SELECT sa.*, p.nom_prenoms AS militaire_nom, g.libelle AS grade_libelle
FROM service_affectation sa
LEFT JOIN personnel p ON p.id = sa.militaire_id
LEFT JOIN grade g ON g.id = p.grade_id
WHERE sa.service_poste_id = ?
ORDER BY sa.role_service ASC, (g.ordre / 100) ASC, g.ordre DESC, p.nom_prenoms ASC
''', [posteId]);
    return rows.map(AffectationService.fromMap).toList();
  }

  Future<int> creerPoste(
    ServicePoste poste, {
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('service_poste', {
      'service_id': poste.serviceId,
      'parent_id': poste.parentId,
      'libelle': poste.libelle,
      'type': poste.type,
      'effectif_requis': poste.effectifRequis,
      'creneau_debut': poste.creneauDebut,
      'creneau_fin': poste.creneauFin,
      'ordre': poste.ordre,
      'observation': poste.observation,
      'created_at': now,
    });
    await Journal.tracer(db,
        action: 'CREATE',
        entite: 'service_poste',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: {'libelle': poste.libelle, 'type': poste.type});
    await Journal.enfiler(db,
        entite: 'service_poste', entiteId: '$id', action: 'CREATE');
    return id;
  }

  Future<void> supprimerPoste(int id,
      {int? utilisateurId, String? utilisateurNom}) async {
    await db
        .delete('service_affectation', where: 'service_poste_id = ?', whereArgs: [id]);
    await db.delete('service_poste', where: 'parent_id = ?', whereArgs: [id]);
    await db.delete('service_poste', where: 'id = ?', whereArgs: [id]);
    await Journal.tracer(db,
        action: 'DELETE',
        entite: 'service_poste',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom);
    await Journal.enfiler(db,
        entite: 'service_poste', entiteId: '$id', action: 'DELETE');
  }

  /// Affecte un militaire a un poste. Remplace automatiquement le titulaire
  /// pour les roles uniques (chef de poste, adjoint).
  Future<int> affecterPoste({
    required int serviceId,
    required int posteId,
    required int militaireId,
    required String role,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    if (role == 'CHEF_POSTE' || role == 'ADJOINT') {
      await db.delete('service_affectation',
          where: 'service_poste_id = ? AND role_service = ?',
          whereArgs: [posteId, role]);
    }
    // Un militaire ne peut occuper qu'un seul poste dans un meme service :
    // on retire son eventuelle affectation existante avant d'inserer.
    await db.delete('service_affectation',
        where: 'service_id = ? AND militaire_id = ?',
        whereArgs: [serviceId, militaireId]);
    final id = await db.insert('service_affectation', {
      'service_id': serviceId,
      'militaire_id': militaireId,
      'role_service': role,
      'present': 1,
      'service_poste_id': posteId,
    });
    await Journal.tracer(db,
        action: 'AFFECT_POSTE',
        entite: 'service_poste',
        entiteId: '$posteId',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: {'militaire_id': militaireId, 'role': role});
    await Journal.enfiler(db,
        entite: 'service_poste', entiteId: '$posteId', action: 'AFFECT_POSTE');
    return id;
  }

  // ---------------------------------------------------------------------------
  // Roles propres a l'astreinte.
  // ---------------------------------------------------------------------------
  Future<List<ServiceRole>> roles(int serviceId) async {
    final rows = await db.query('service_role',
        where: 'service_id = ?',
        whereArgs: [serviceId],
        orderBy: 'ordre ASC, id ASC');
    final liste = rows.map(ServiceRole.fromMap).toList();
    for (final r in liste) {
      r.affectations = await _affectationsRole(r.id!);
      r.gradesAutorises = await _gradesRole(r.id!);
    }
    return liste;
  }

  Future<Set<int>> _gradesRole(int roleId) async {
    final rows = await db.query('service_grade_autorise',
        columns: ['grade_id'],
        where: 'cible_type = ? AND cible_id = ?',
        whereArgs: [CibleGrade.role, roleId]);
    return rows.map((r) => r['grade_id'] as int).toSet();
  }

  Future<List<AffectationService>> _affectationsRole(int roleId) async {
    final rows = await db.rawQuery('''
SELECT sa.*, p.nom_prenoms AS militaire_nom, g.libelle AS grade_libelle
FROM service_affectation sa
LEFT JOIN personnel p ON p.id = sa.militaire_id
LEFT JOIN grade g ON g.id = p.grade_id
WHERE sa.service_role_id = ?
ORDER BY p.nom_prenoms ASC
''', [roleId]);
    return rows.map(AffectationService.fromMap).toList();
  }

  /// Cree les roles d'astreinte par defaut si le service n'en possede aucun.
  Future<void> assurerRolesParDefaut(int serviceId) async {
    final n = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM service_role WHERE service_id = ?', [serviceId]));
    if ((n ?? 0) > 0) return;
    var ordre = 0;
    for (final d in kRolesAstreinte) {
      await db.insert('service_role', {
        'service_id': serviceId,
        'code': d.code,
        'libelle': d.libelle,
        'nombre_requis': d.nombre,
        'ordre': ordre++,
      });
    }
  }

  Future<int> creerRole(ServiceRole role,
      {int? utilisateurId, String? utilisateurNom}) async {
    final id = await db.insert('service_role', {
      'service_id': role.serviceId,
      'code': role.code,
      'libelle': role.libelle,
      'nombre_requis': role.nombreRequis,
      'ordre': role.ordre,
    });
    await Journal.tracer(db,
        action: 'CREATE',
        entite: 'service_role',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: {'libelle': role.libelle});
    await Journal.enfiler(db,
        entite: 'service_role', entiteId: '$id', action: 'CREATE');
    return id;
  }

  Future<void> modifierRoleNombre(int roleId, int nombreRequis) async {
    await db.update('service_role', {'nombre_requis': nombreRequis},
        where: 'id = ?', whereArgs: [roleId]);
  }

  Future<void> supprimerRole(int roleId,
      {int? utilisateurId, String? utilisateurNom}) async {
    await db.delete('service_affectation',
        where: 'service_role_id = ?', whereArgs: [roleId]);
    await db.delete('service_role', where: 'id = ?', whereArgs: [roleId]);
    await Journal.tracer(db,
        action: 'DELETE',
        entite: 'service_role',
        entiteId: '$roleId',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom);
    await Journal.enfiler(db,
        entite: 'service_role', entiteId: '$roleId', action: 'DELETE');
  }

  Future<int> affecterRole({
    required int serviceId,
    required int roleId,
    required int militaireId,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    // Un militaire ne peut occuper qu'un seul poste dans un meme service :
    // on retire son eventuelle affectation existante avant d'inserer.
    await db.delete('service_affectation',
        where: 'service_id = ? AND militaire_id = ?',
        whereArgs: [serviceId, militaireId]);
    final id = await db.insert('service_affectation', {
      'service_id': serviceId,
      'militaire_id': militaireId,
      'role_service': 'ASTREINTE',
      'present': 1,
      'service_role_id': roleId,
    });
    await Journal.tracer(db,
        action: 'AFFECT_ROLE',
        entite: 'service_role',
        entiteId: '$roleId',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: {'militaire_id': militaireId});
    await Journal.enfiler(db,
        entite: 'service_role', entiteId: '$roleId', action: 'AFFECT_ROLE');
    return id;
  }

  Future<void> retirerAffectation(int affectationId) async {
    await db.delete('service_affectation',
        where: 'id = ?', whereArgs: [affectationId]);
  }

  // ---------------------------------------------------------------------------
  // QRF (Piquet / Intervention) : en liste ou par equipage d'engin blinde.
  // ---------------------------------------------------------------------------
  Future<List<ServiceQrf>> qrfs(int serviceId) async {
    final rows = await db.query('service_qrf',
        where: 'service_id = ?',
        whereArgs: [serviceId],
        orderBy: 'ordre ASC, id ASC');
    final liste = rows.map(ServiceQrf.fromMap).toList();
    for (final q in liste) {
      q.membres = await _membresQrf(q.id!);
    }
    return liste;
  }

  Future<List<ServiceQrfMembre>> _membresQrf(int qrfId) async {
    final rows = await db.rawQuery('''
SELECT m.*, p.nom_prenoms AS militaire_nom, g.code AS grade_code
FROM service_qrf_membre m
LEFT JOIN personnel p ON p.id = m.militaire_id
LEFT JOIN grade g ON g.id = p.grade_id
WHERE m.qrf_id = ?
ORDER BY m.ordre ASC, m.id ASC
''', [qrfId]);
    return rows.map(ServiceQrfMembre.fromMap).toList();
  }

  Future<int> creerQrf(ServiceQrf qrf,
      {int? utilisateurId, String? utilisateurNom}) async {
    final id = await db.insert('service_qrf', {
      'service_id': qrf.serviceId,
      'type': qrf.type,
      'mode': qrf.mode,
      'engin': qrf.engin,
      'effectif': qrf.effectif,
      'nombre_equipages': qrf.nombreEquipages,
      'ordre': qrf.ordre,
      'grades_fonctions': qrf.gradesFonctionsJson,
      'created_at': DateTime.now().toIso8601String(),
    });
    var ordre = 0;
    for (final m in qrf.membres) {
      if (m.militaireId == null) continue;
      await db.insert('service_qrf_membre', {
        'qrf_id': id,
        'fonction': m.fonction,
        'militaire_id': m.militaireId,
        'equipage': m.equipage,
        'ordre': ordre++,
      });
    }
    await Journal.tracer(db,
        action: 'CREATE',
        entite: 'service_qrf',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: {'type': qrf.type, 'mode': qrf.mode, 'engin': qrf.engin});
    await Journal.enfiler(db,
        entite: 'service_qrf',
        entiteId: '$id',
        action: 'CREATE',
        payload: {'type': qrf.type, 'mode': qrf.mode});
    return id;
  }

  Future<void> supprimerQrf(int qrfId,
      {int? utilisateurId, String? utilisateurNom}) async {
    await db.delete('service_qrf_membre',
        where: 'qrf_id = ?', whereArgs: [qrfId]);
    await db.delete('service_qrf', where: 'id = ?', whereArgs: [qrfId]);
    await Journal.tracer(db,
        action: 'DELETE',
        entite: 'service_qrf',
        entiteId: '$qrfId',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom);
    await Journal.enfiler(db,
        entite: 'service_qrf', entiteId: '$qrfId', action: 'DELETE');
  }

  /// Met a jour les grades autorises par poste (fonction) d'un equipage QRF.
  Future<void> definirGradesQrf(
    int qrfId,
    Map<String, Set<int>> grades, {
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    final json = encoderGradesFonctions(grades);
    await db.update('service_qrf', {'grades_fonctions': json},
        where: 'id = ?', whereArgs: [qrfId]);
    await Journal.tracer(db,
        action: 'UPDATE',
        entite: 'service_qrf',
        entiteId: '$qrfId',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: {'grades_fonctions': json});
    await Journal.enfiler(db,
        entite: 'service_qrf', entiteId: '$qrfId', action: 'UPDATE');
  }

  Future<int> ajouterMembreQrf({
    required int qrfId,
    required String fonction,
    required int militaireId,
    int equipage = 1,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    final ordre = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM service_qrf_membre WHERE qrf_id = ?',
            [qrfId])) ??
        0;
    final id = await db.insert('service_qrf_membre', {
      'qrf_id': qrfId,
      'fonction': fonction,
      'militaire_id': militaireId,
      'equipage': equipage,
      'ordre': ordre,
    });
    await Journal.tracer(db,
        action: 'AFFECT_QRF',
        entite: 'service_qrf',
        entiteId: '$qrfId',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: {'militaire_id': militaireId, 'fonction': fonction});
    await Journal.enfiler(db,
        entite: 'service_qrf', entiteId: '$qrfId', action: 'AFFECT_QRF');
    return id;
  }

  Future<void> retirerMembreQrf(int membreId) async {
    await db.delete('service_qrf_membre',
        where: 'id = ?', whereArgs: [membreId]);
  }

  /// Definit les grades autorises pour une responsabilite (poste) ou un role.
  /// Un ensemble vide signifie "tous les grades".
  Future<void> definirGrades({
    required int serviceId,
    required String cibleType,
    required int cibleId,
    required Set<int> gradeIds,
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    await db.delete('service_grade_autorise',
        where: 'cible_type = ? AND cible_id = ?',
        whereArgs: [cibleType, cibleId]);
    for (final g in gradeIds) {
      await db.insert(
        'service_grade_autorise',
        {
          'service_id': serviceId,
          'cible_type': cibleType,
          'cible_id': cibleId,
          'grade_id': g,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    final trace = {'cible': '$cibleType/$cibleId', 'grades': gradeIds.toList()};
    await Journal.tracer(db,
        action: 'SET_GRADES',
        entite: 'service_grade_autorise',
        entiteId: '$cibleType/$cibleId',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom,
        apres: trace);
    await Journal.enfiler(db,
        entite: 'service_grade_autorise',
        entiteId: '$cibleType/$cibleId',
        action: 'SET_GRADES',
        payload: trace);
  }

  static String _jour(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Positions derivees des services d'astreinte en cours au moment [moment]
  /// (defaut : maintenant). Renvoie, pour chaque militaire concerne, la
  /// precision de position : "En service" s'il est dans un service d'astreinte
  /// actif, ou "De faction" s'il tient le creneau de faction de 2h en cours.
  Future<Map<int, String>> positionsService({
    DateTime? moment,
    int? sectionId,
  }) async {
    final positions = await _positionsServiceCalculees(moment);
    if (sectionId == null) return positions;
    // Restreint les positions derivees au peloton du chef de peloton.
    final ids = <int>{};
    final rows = await db.rawQuery(
        'SELECT p.id AS id FROM personnel p '
        'JOIN affectation_organique ao ON ao.militaire_id = p.id AND ao.actif = 1 '
        'WHERE ao.section_id = ?',
        [sectionId]);
    for (final r in rows) {
      final id = r['id'] as int?;
      if (id != null) ids.add(id);
    }
    return {for (final e in positions.entries) if (ids.contains(e.key)) e.key: e.value};
  }

  Future<Map<int, String>> _positionsServiceCalculees(DateTime? moment) async {
    final maintenant = moment ?? DateTime.now();
    final positions = <int, String>{};
    final rows = await db.rawQuery('''
SELECT sv.*, ts.code AS type_code, ts.libelle AS type_libelle,
       po.libelle AS poste_libelle
FROM service sv
LEFT JOIN type_service ts ON ts.id = sv.type_service_id
LEFT JOIN poste po ON po.id = sv.poste_id
WHERE ts.code = 'ASTREINTE'
''');
    for (final r in rows) {
      final svc = ServiceModel.fromMap(r);
      if (!_serviceEnCours(svc, maintenant)) continue;
      final affs = await affectations(svc.id!);
      for (final a in affs) {
        if (a.militaireId != null) positions[a.militaireId!] = 'En service';
      }
      final membresQrf = await db.rawQuery('''
SELECT m.militaire_id AS militaire_id
FROM service_qrf_membre m
JOIN service_qrf q ON q.id = m.qrf_id
WHERE q.service_id = ?
''', [svc.id]);
      for (final m in membresQrf) {
        final id = m['militaire_id'] as int?;
        if (id != null && !positions.containsKey(id)) {
          positions[id] = 'En service';
        }
      }
      final debut = svc.debutDt;
      if (debut == null) continue;
      final parPoste = <int, List<AffectationService>>{};
      for (final a in affs) {
        if (a.roleService == 'FACTION' && a.servicePosteId != null) {
          (parPoste[a.servicePosteId!] ??= []).add(a);
        }
      }
      for (final faction in parPoste.values) {
        final creneaux = creneauxFaction2h(
          debut: debut,
          dureeHeures: svc.dureeHeures,
          faction: faction,
        );
        for (final c in creneaux) {
          if (!maintenant.isBefore(c.debut) && maintenant.isBefore(c.fin)) {
            final id = c.affectation?.militaireId;
            if (id != null) positions[id] = 'De faction';
          }
        }
      }
    }
    return positions;
  }

  bool _serviceEnCours(ServiceModel svc, DateTime moment) {
    final debut = svc.debutDt;
    if (debut != null) {
      final fin = debut.add(Duration(hours: svc.dureeHeures));
      return !moment.isBefore(debut) && moment.isBefore(fin);
    }
    return svc.date == _jour(moment);
  }

  /// Militaires actifs proposes pour le garnissage des postes et roles.
  /// Militaires selectionnables pour un service : uniquement les presents
  /// (dernier statut disponible).
  Future<List<MilitaireOption>> militaires({int? sectionId}) async {
    final filtre = sectionId == null
        ? ''
        : ' AND p.id IN (SELECT ao.militaire_id FROM affectation_organique ao '
            'WHERE ao.actif = 1 AND ao.section_id = ?)';
    final rows = await db.rawQuery('''
SELECT p.id AS id, p.nom_prenoms AS nom_prenoms,
       g.code AS grade_code, g.libelle AS grade_libelle, g.id AS grade_id
FROM personnel p
LEFT JOIN grade g ON g.id = p.grade_id
LEFT JOIN statut st ON st.id = (
  SELECT s.statut_id FROM situation s
  WHERE s.militaire_id = p.id
  ORDER BY s.date_debut DESC, s.id DESC LIMIT 1)
WHERE p.actif = 1 AND st.disponible = 1$filtre
ORDER BY (g.ordre / 100) ASC, g.ordre DESC, p.nom_prenoms ASC
''', [if (sectionId != null) sectionId]);
    return rows
        .map((r) => MilitaireOption(
              id: r['id'] as int,
              nom: (r['nom_prenoms'] ?? '') as String,
              gradeLibelle: r['grade_libelle'] as String?,
              gradeCode: r['grade_code'] as String?,
              gradeId: r['grade_id'] as int?,
            ))
        .toList();
  }
}
