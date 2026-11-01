import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../core/positions.dart';
import '../models/dashboard_stats.dart';
import '../models/spa.dart';
import 'journal.dart';

/// Depot de calcul des indicateurs et de generation des etats.
class RapportRepository {
  final Database db;
  RapportRepository(this.db);

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Indique si une table existe dans la base (tables optionnelles).
  Future<bool> _tableExiste(String nom) async {
    final r = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        [nom]);
    return r.isNotEmpty;
  }

  Future<DashboardStats> tableauDeBord({int? sectionId}) async {
    final stats = DashboardStats();

    // Restriction a un peloton (Chef de Peloton) le cas echeant.
    final filtre = sectionId == null
        ? ''
        : ' AND p.id IN (SELECT ao.militaire_id FROM affectation_organique ao '
            'WHERE ao.actif = 1 AND ao.section_id = ?)';
    final args = <Object?>[if (sectionId != null) sectionId];

    final total = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM personnel p WHERE p.actif = 1$filtre', args);
    stats.effectifTotal = (total.first['n'] as int?) ?? 0;

    final parStatut = await db.rawQuery('''
SELECT st.code AS code, st.disponible AS dispo, COUNT(*) AS n
FROM personnel p
JOIN situation s ON s.id = (
  SELECT s2.id FROM situation s2 WHERE s2.militaire_id = p.id
  ORDER BY s2.date_debut DESC, s2.id DESC LIMIT 1)
JOIN statut st ON st.id = s.statut_id
WHERE p.actif = 1$filtre
GROUP BY st.code, st.disponible
''', args);
    for (final r in parStatut) {
      final code = (r['code'] ?? '') as String;
      final n = (r['n'] as int?) ?? 0;
      final dispo = ((r['dispo'] as int?) ?? 0) == 1;
      switch (code) {
        case 'EN_SERVICE':
          stats.presents += n;
          break;
        case 'EN_MISSION':
          stats.mission += n;
          break;
        case 'EN_STAGE':
          stats.stage += n;
          break;
        case 'MISE_A_DISPOSITION':
          stats.miseADisposition += n;
          break;
        case 'EN_PERMISSION':
        case 'EN_CONGE':
          stats.permission += n;
          break;
        case 'MALADE':
          stats.malades += n;
          break;
        case 'REPOS_MEDICAL':
          stats.reposMedical += n;
          break;
        case 'ABSENT':
          stats.absent += n;
          break;
      }
      if (dispo) {
        stats.disponible += n;
      } else {
        stats.indisponible += n;
      }
    }

    // Repartition detaillee : rubrique > precision > personnes (debut / duree).
    final detail = await db.rawQuery('''
SELECT p.nom_prenoms AS nom, p.position AS position,
       p.position_precision AS precision, p.position_debut AS debut,
       p.position_duree AS duree, g.code AS grade_code
FROM personnel p
LEFT JOIN grade g ON g.id = p.grade_id
WHERE p.actif = 1$filtre
''', args);
    final parRubrique = <String, Map<String, List<PersonnePosition>>>{};
    for (final r in detail) {
      final posBrute = (r['position'] as String? ?? '').trim();
      final rubrique = positionDepuisStatutCode(statutCodeDepuisPosition(posBrute));
      final prec = (r['precision'] as String? ?? '').trim();
      final cle = prec.isEmpty ? 'Sans précision' : prec;
      final nom = [
        (r['grade_code'] as String? ?? '').trim(),
        (r['nom'] as String? ?? '').trim(),
      ].where((e) => e.isNotEmpty).join(' ');
      ((parRubrique[rubrique] ??= {})[cle] ??= <PersonnePosition>[])
          .add(PersonnePosition(
        nom: nom,
        debut: r['debut'] as String?,
        duree: r['duree'] as String?,
      ));
    }
    final rubriques = <RubriqueStats>[];
    for (final rub in kPositions) {
      final map = parRubrique[rub];
      if (map == null) continue;
      rubriques.add(_rubriqueStats(rub, map));
    }
    for (final rub in parRubrique.keys) {
      if (kPositions.contains(rub)) continue;
      rubriques.add(_rubriqueStats(rub, parRubrique[rub]!));
    }
    stats.repartition = rubriques;

    final sections = await db.rawQuery('''
SELECT sec.id AS section_id, sec.libelle AS libelle, COUNT(*) AS n,
  SUM(CASE WHEN st.disponible = 1 THEN 1 ELSE 0 END) AS dispo
FROM personnel p
JOIN affectation_organique ao ON ao.militaire_id = p.id AND ao.actif = 1
JOIN section sec ON sec.id = ao.section_id
JOIN situation s ON s.id = (
  SELECT s2.id FROM situation s2 WHERE s2.militaire_id = p.id
  ORDER BY s2.date_debut DESC, s2.id DESC LIMIT 1)
JOIN statut st ON st.id = s.statut_id
WHERE p.actif = 1$filtre
GROUP BY sec.id, sec.libelle, sec.ordre
ORDER BY sec.ordre ASC
''', args);
    stats.parSection = sections
        .map((r) => SectionStats(
              sectionId: (r['section_id'] as int?) ?? 0,
              libelle: (r['libelle'] ?? '') as String,
              effectif: (r['n'] as int?) ?? 0,
              disponible: (r['dispo'] as int?) ?? 0,
            ))
        .toList();

    // Armement : tables optionnelles (fonctionnalite desactivee). On ne les
    // interroge que si elles existent, sinon le tableau de bord planterait sur
    // une installation neuve.
    if (await _tableExiste('arme')) {
      final armes = await db.rawQuery('''
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN etat = 'EN_SERVICE' THEN 1 ELSE 0 END) AS en_service,
  SUM(CASE WHEN etat IN ('REPARATION','REFORMEE') THEN 1 ELSE 0 END) AS hs
FROM arme
''');
      stats.armesTotal = (armes.first['total'] as int?) ?? 0;
      stats.armesEnService = (armes.first['en_service'] as int?) ?? 0;
      stats.armesDefectueuses = (armes.first['hs'] as int?) ?? 0;
    }

    if (await _tableExiste('dotation')) {
      final dotees = await db.rawQuery(
          'SELECT COUNT(*) AS n FROM dotation WHERE date_retour IS NULL');
      stats.armesDotees = (dotees.first['n'] as int?) ?? 0;
    }

    if (await _tableExiste('munition')) {
      final muns = await db.rawQuery(
          'SELECT COUNT(*) AS n FROM munition WHERE stock_actuel <= seuil_alerte');
      stats.munitionsAlerte = (muns.first['n'] as int?) ?? 0;
    }

    final services = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM service WHERE date = ?', [_today()]);
    stats.servicesDuJour = (services.first['n'] as int?) ?? 0;

    stats.outboxEnAttente = await Journal.enAttente(db);
    return stats;
  }

  /// Construit la repartition d'une rubrique a partir de ses precisions.
  RubriqueStats _rubriqueStats(
      String libelle, Map<String, List<PersonnePosition>> map) {
    final precisions = <PrecisionStats>[];
    var total = 0;
    for (final e in map.entries) {
      total += e.value.length;
      precisions.add(PrecisionStats(
          libelle: e.key, total: e.value.length, personnes: e.value));
    }
    precisions.sort((a, b) {
      if (a.libelle == 'Sans précision') return 1;
      if (b.libelle == 'Sans précision') return -1;
      return a.libelle.compareTo(b.libelle);
    });
    return RubriqueStats(libelle: libelle, total: total, precisions: precisions);
  }

  /// Enregistre un etat quotidien figé (historisation + trace).
  Future<int> enregistrerEtatQuotidien({
    required String type,
    String? nom,
    String? duree,
    Map<String, int>? composition,
    List<String>? statutCodes,
    bool? disponible,
    List<Map<String, Object?>>? concernes,
    int? utilisateurId,
    int? sectionId,
  }) async {
    final s = await tableauDeBord(sectionId: sectionId);
    final liste = concernes ??
        await _personnelsConcernes(
          statutCodes: statutCodes,
          disponible: disponible,
          sectionId: sectionId,
        );
    final id = await db.insert('etat_quotidien', {
      'date': _today(),
      'type': type,
      'section_id': sectionId,
      'effectif_total': s.effectifTotal,
      'total_mission': s.mission,
      'total_stage': s.stage,
      'total_mise_a_disposition': s.miseADisposition,
      'total_permission': s.permission,
      'total_malades': s.malades,
      'total_repos_medical': s.reposMedical,
      'total_absent': s.absent,
      'total_indisponible': s.indisponible,
      'total_disponible': s.disponible,
      'contenu_json': jsonEncode({
        'nom': nom,
        'duree': duree,
        if (composition != null) 'composition': composition,
        'parSection': s.parSection
            .map((e) => {'libelle': e.libelle, 'effectif': e.effectif, 'disponible': e.disponible})
            .toList(),
        'concernes': liste,
      }),
      'genere_par': utilisateurId,
      'created_at': DateTime.now().toIso8601String(),
    });
    await Journal.tracer(db,
        action: 'GENERATE_ETAT',
        entite: 'etat_quotidien',
        entiteId: '$id',
        utilisateurId: utilisateurId);
    await Journal.enfiler(db,
        entite: 'etat_quotidien', entiteId: '$id', action: 'GENERATE');
    return id;
  }

  Future<List<Map<String, Object?>>> _personnelsConcernes({
    List<String>? statutCodes,
    bool? disponible,
    int? sectionId,
  }) async {
    final where = <String>['p.actif = 1'];
    final args = <Object?>[];
    if (sectionId != null) {
      where.add('p.id IN (SELECT ao.militaire_id FROM affectation_organique ao '
          'WHERE ao.actif = 1 AND ao.section_id = ?)');
      args.add(sectionId);
    }
    if (statutCodes != null && statutCodes.isNotEmpty) {
      where.add('st.code IN (${List.filled(statutCodes.length, '?').join(', ')})');
      args.addAll(statutCodes);
    }
    if (disponible != null) {
      where.add('st.disponible = ?');
      args.add(disponible ? 1 : 0);
    }
    final rows = await db.rawQuery('''
SELECT p.nom_prenoms AS nom, p.matricule AS matricule, st.libelle AS statut
FROM personnel p
JOIN situation s ON s.id = (
  SELECT s2.id FROM situation s2 WHERE s2.militaire_id = p.id
  ORDER BY s2.date_debut DESC, s2.id DESC LIMIT 1)
JOIN statut st ON st.id = s.statut_id
WHERE ${where.join(' AND ')}
ORDER BY p.nom_prenoms ASC
''', args);
    return rows
        .map((r) => {
              'nom': r['nom'],
              'matricule': r['matricule'],
              'statut': r['statut'],
            })
        .toList();
  }

  static const List<String> _moisFr = [
    'JANVIER', 'FEVRIER', 'MARS', 'AVRIL', 'MAI', 'JUIN',
    'JUILLET', 'AOUT', 'SEPTEMBRE', 'OCTOBRE', 'NOVEMBRE', 'DECEMBRE',
  ];

  static String _dateSituation() {
    final d = DateTime.now().toUtc();
    final j = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final mn = d.minute.toString().padLeft(2, '0');
    return 'DU $j ${_moisFr[d.month - 1]} ${d.year} $h${mn}Z';
  }

  /// Construit le document "SPA" (Situation des Personnels Absents) a partir
  /// des donnees saisies : effectifs par categorie, repartition par position
  /// et precision, totaux et liste nominative des absents.
  Future<SpaData> situationSpa({int? sectionId}) async {
    final filtre = sectionId == null
        ? ''
        : ' AND p.id IN (SELECT ao.militaire_id FROM affectation_organique ao '
            'WHERE ao.actif = 1 AND ao.section_id = ?)';
    final personnel = await db.rawQuery('''
SELECT p.nom_prenoms AS nom, p.position AS position,
       p.position_precision AS precision,
       g.code AS grade_code, cat.code AS cat_code
FROM personnel p
LEFT JOIN grade g ON g.id = p.grade_id
LEFT JOIN categorie cat ON cat.id = COALESCE(p.categorie_id, g.categorie_id)
WHERE p.actif = 1$filtre
''', [if (sectionId != null) sectionId]);

    final theo = <int>[0, 0, 0];
    final present = <int>[0, 0, 0];
    final parPos = <String, List<int>>{};
    final parPosPrec = <String, List<int>>{};
    final obsPos = <String, List<String>>{};
    final obsPosPrec = <String, List<String>>{};

    for (final r in personnel) {
      final i = _catIndex(r['cat_code'] as String?);
      final posBrute = (r['position'] as String? ?? '').trim();
      final rubrique =
          positionDepuisStatutCode(statutCodeDepuisPosition(posBrute));
      final precDb = (r['precision'] as String? ?? '').trim();
      final precision =
          precDb.isNotEmpty ? precDb : _devinerPrecision(rubrique, posBrute);
      final grade = (r['grade_code'] as String? ?? '').trim();
      final nom = (r['nom'] as String? ?? '').trim();
      final nomComplet = [grade, nom].where((e) => e.isNotEmpty).join(' ');
      theo[i]++;
      if (_sansAccent(rubrique).contains('PRESENT')) {
        present[i]++;
      } else {
        _inc(parPos, rubrique, i);
        if (precision.isNotEmpty) {
          _inc(parPosPrec, '$rubrique\u0000$precision', i);
          (obsPosPrec['$rubrique\u0000$precision'] ??= <String>[])
              .add(nomComplet);
        } else {
          (obsPos[rubrique] ??= <String>[]).add(nomComplet);
        }
      }
    }

    final rows = <SpaRow>[];
    rows.add(SpaRow(
      libelle: 'EFFECTIF THEORIQUE',
      officiers: theo[0],
      sousOfficiers: theo[1],
      hommesDuRang: theo[2],
      type: SpaType.effectif,
    ));
    rows.add(SpaRow(
      libelle: 'EFFECTIF PRATIQUE (AVEC HORS TED)',
      officiers: theo[0],
      sousOfficiers: theo[1],
      hommesDuRang: theo[2],
      type: SpaType.effectif,
    ));

    final ordre = <String>[];
    for (final p in kPositions) {
      if (!_sansAccent(p).contains('PRESENT')) ordre.add(p);
    }
    for (final k in parPos.keys) {
      if (!ordre.contains(k)) ordre.add(k);
    }

    for (final base in ordre) {
      final counts = parPos[base];
      final precs = <String>[...precisionsPourPosition(base)];
      for (final k in parPosPrec.keys) {
        final parts = k.split('\u0000');
        if (parts[0] == base && !precs.contains(parts[1])) precs.add(parts[1]);
      }
      final aDesGens = counts != null &&
          (counts[0] + counts[1] + counts[2] > 0);
      if (!aDesGens && precs.every((p) => parPosPrec['$base\u0000$p'] == null)) {
        continue;
      }
      rows.add(SpaRow(
        libelle: base,
        officiers: counts?[0] ?? 0,
        sousOfficiers: counts?[1] ?? 0,
        hommesDuRang: counts?[2] ?? 0,
        type: SpaType.rubrique,
        observation: (obsPos[base] ?? const []).join(' + '),
      ));
      for (final prec in precs) {
        final c = parPosPrec['$base\u0000$prec'];
        if (c == null) continue;
        rows.add(SpaRow(
          libelle: prec,
          officiers: c[0],
          sousOfficiers: c[1],
          hommesDuRang: c[2],
          type: SpaType.sousRubrique,
          observation: (obsPosPrec['$base\u0000$prec'] ?? const []).join(' + '),
        ));
      }
    }

    final indispo = <int>[
      theo[0] - present[0],
      theo[1] - present[1],
      theo[2] - present[2],
    ];
    rows.add(SpaRow(
      libelle: 'TOTAL INDISPONIBLE',
      officiers: indispo[0],
      sousOfficiers: indispo[1],
      hommesDuRang: indispo[2],
      type: SpaType.total,
    ));
    rows.add(SpaRow(
      libelle: 'TOTAL DISPONIBLE',
      officiers: present[0],
      sousOfficiers: present[1],
      hommesDuRang: present[2],
      type: SpaType.total,
    ));

    return SpaData(
      unite: AppUnit.libelle,
      dateSituation: _dateSituation(),
      rows: rows,
    );
  }

  static void _inc(Map<String, List<int>> map, String key, int i) {
    (map[key] ??= <int>[0, 0, 0])[i]++;
  }

  /// Retire les accents et passe en majuscules (comparaison "Present").
  static String _sansAccent(String texte) {
    const from = 'ÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ';
    const to = 'AAAEEEEIIOOUUUC';
    final up = texte.toUpperCase();
    final sb = StringBuffer();
    for (final ch in up.split('')) {
      final idx = from.indexOf(ch);
      sb.write(idx >= 0 ? to[idx] : ch);
    }
    return sb.toString();
  }

  /// Devine la precision a partir du libelle de position brut du seed
  /// (ex: "MAD/BIM HAITI" -> "HAITI") quand aucune precision n'est saisie.
  static String _devinerPrecision(String rubrique, String posBrute) {
    final up = _sansAccent(posBrute);
    for (final prec in kPositionPrecisions[rubrique] ?? const <String>[]) {
      final token = _sansAccent(prec);
      if (token.isNotEmpty && up.contains(token)) return prec;
    }
    return '';
  }

  int _catIndex(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'OFF':
        return 0;
      case 'S-OFF':
      case 'S/OFF':
      case 'SOFF':
        return 1;
      case 'MDR':
      default:
        return 2;
    }
  }

  Future<List<Map<String, Object?>>> historiqueEtats({
    int? sectionId,
    int limite = 30,
  }) {
    return db.query(
      'etat_quotidien',
      where: sectionId == null ? null : 'section_id = ?',
      whereArgs: sectionId == null ? null : [sectionId],
      orderBy: 'created_at DESC',
      limit: limite,
    );
  }

  /// Supprime un etat historise.
  Future<void> supprimerEtat(
    int id, {
    int? utilisateurId,
    String? utilisateurNom,
  }) async {
    await db.delete('etat_quotidien', where: 'id = ?', whereArgs: [id]);
    await Journal.tracer(db,
        action: 'DELETE_ETAT',
        entite: 'etat_quotidien',
        entiteId: '$id',
        utilisateurId: utilisateurId,
        utilisateurNom: utilisateurNom);
    await Journal.enfiler(db,
        entite: 'etat_quotidien', entiteId: '$id', action: 'DELETE');
  }
}
