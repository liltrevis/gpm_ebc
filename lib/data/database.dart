import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/positions.dart';
import '../core/rbac.dart';
import 'seed_affectations.dart';
import 'seed_data.dart';

/// Couche d'acces a la base SQLite locale (offline-first).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const int _version = 24;
  static const String _dbName = 'gpm_ebc.db';

  /// Version courante du schema (utilisee pour valider une sauvegarde).
  static int get version => _version;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await _dossierBase();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Bases anciennes (donnees partielles v1/v2) : reinitialisation complete
        // avec le jeu de donnees reel du fichier principal.
        if (oldVersion < 3) {
          await db.execute('PRAGMA foreign_keys = OFF');
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
          );
          for (final t in tables) {
            await db.execute('DROP TABLE IF EXISTS "${t['name']}"');
          }
          await db.execute('PRAGMA foreign_keys = ON');
          await _createSchema(db);
          await _seed(db);
        }
        // v4 : libelle du statut "En service" renomme en "Present".
        if (oldVersion < 4) {
          await db.update('statut', {'libelle': 'Présent'},
              where: "code = 'EN_SERVICE'");
        }
        // v5 : terminologie "Section" renommee en "Peloton".
        if (oldVersion < 5) {
          await db.update('section', {'libelle': '1er Peloton'},
              where: "code = 'S1'");
          await db.update('section', {'libelle': '2e Peloton'},
              where: "code = 'S2'");
          await db.update('section', {'libelle': '3e Peloton'},
              where: "code = 'S3'");
          await db.update('fonction', {'libelle': 'Chef de peloton'},
              where: "code = 'CMD_SECTION'");
        }
        // v6 : les positions se limitent aux 8 rubriques de "Repartition du
        // personnel" (aligne chaque position sur le statut courant).
        if (oldVersion < 6) {
          final rows = await db.rawQuery('''
SELECT p.id AS id, st.code AS code
FROM personnel p
LEFT JOIN situation s ON s.id = (
  SELECT s2.id FROM situation s2 WHERE s2.militaire_id = p.id
  ORDER BY s2.date_debut DESC, s2.id DESC LIMIT 1)
LEFT JOIN statut st ON st.id = s.statut_id
''');
          for (final r in rows) {
            await db.update(
              'personnel',
              {'position': positionDepuisStatutCode(r['code'] as String?)},
              where: 'id = ?',
              whereArgs: [r['id']],
            );
          }
        }
        // v7 : precision de la position (sous-categorie : LOMO NORD, INTERNE...)
        // + table de reference des precisions (elles-memes ajoutables).
        if (oldVersion < 7) {
          await db.execute(_sqlPrecisionPosition);
          final cols = await db.rawQuery('PRAGMA table_info(personnel)');
          final aColonne =
              cols.any((c) => c['name'] == 'position_precision');
          if (!aColonne) {
            await db.execute(
                'ALTER TABLE personnel ADD COLUMN position_precision TEXT');
          }
          await _seedPrecisions(db, DateTime.now().toIso8601String());
        }
        // v8 : libelle du grade "Clairon" corrige en "Cavalier".
        if (oldVersion < 8) {
          await db.update('grade', {'libelle': 'Cavalier de 1ère classe'},
              where: "code = 'CLIER1'");
          await db.update('grade', {'libelle': 'Cavalier de 2e classe'},
              where: "code = 'CLIER2'");
        }
        // v9 : postes d'un service (principal >> postes basiques + chef/adjoint)
        // et roles propres a l'astreinte (officier de permanence, QRF...).
        if (oldVersion < 9) {
          await db.execute(_sqlServicePoste);
          await db.execute(_sqlServiceRole);
          final cols = await db.rawQuery('PRAGMA table_info(service_affectation)');
          final noms = cols.map((c) => c['name']).toSet();
          if (!noms.contains('service_poste_id')) {
            await db.execute(
                'ALTER TABLE service_affectation ADD COLUMN service_poste_id INTEGER');
          }
          if (!noms.contains('service_role_id')) {
            await db.execute(
                'ALTER TABLE service_affectation ADD COLUMN service_role_id INTEGER');
          }
        }
        // v10 : grades autorises par poste / responsabilite (chef, adjoint,
        // faction) et par role d'astreinte.
        if (oldVersion < 10) {
          await db.execute(_sqlServiceGradeAutorise);
        }
        // v11 : referentiel complet des grades (Officiers, Sous-officiers,
        // Militaires du rang) avec leur categorie statutaire.
        if (oldVersion < 11) {
          await _majGrades(db);
        }
        // v12 : duree de service (24h / 48h) et date/heure de fin calculee.
        if (oldVersion < 12) {
          final cols = await db.rawQuery('PRAGMA table_info(service)');
          final noms = cols.map((c) => c['name']).toSet();
          if (!noms.contains('duree_heures')) {
            await db.execute(
                'ALTER TABLE service ADD COLUMN duree_heures INTEGER DEFAULT 24');
          }
          if (!noms.contains('date_fin')) {
            await db.execute('ALTER TABLE service ADD COLUMN date_fin TEXT');
          }
        }
        // v13 : renommage de la section "Etat-Major" en "Peloton Cmd".
        if (oldVersion < 13) {
          await db.update('section', {'libelle': 'Peloton Cmd'},
              where: "code = 'EM'");
        }
        // v14 : deux types de service seulement : Astreinte et Autre service.
        if (oldVersion < 14) {
          await db.insert(
              'type_service',
              {'code': 'AUTRE', 'libelle': 'Autre service', 'effectif_requis': 0},
              conflictAlgorithm: ConflictAlgorithm.ignore);
          final autre =
              await db.query('type_service', where: "code = 'AUTRE'");
          final autreId = autre.first['id'] as int;
          await db.update('service', {'type_service_id': autreId},
              where: "type_service_id IN "
                  "(SELECT id FROM type_service WHERE code NOT IN ('ASTREINTE', 'AUTRE'))");
          await db.delete('type_service',
              where: "code NOT IN ('ASTREINTE', 'AUTRE')");
        }
        // v16 : suppression des grades errones "ADJ" (doublon de "ADT") et
        // "MDR" (qui est une categorie de grade, non un grade).
        if (oldVersion < 16) {
          await _supprimerGradesErrones(db);
        }
        // v17 : QRF (Piquet / Intervention), composees en liste ou par
        // equipage d'engin blinde. Remplace l'ancien role d'astreinte "QRF".
        if (oldVersion < 17) {
          await db.execute(_sqlServiceQrf);
          await db.execute(_sqlServiceQrfMembre);
          await db.delete('service_affectation',
              where:
                  'service_role_id IN (SELECT id FROM service_role WHERE code = ?)',
              whereArgs: ['QRF']);
          await db.delete('service_role', where: 'code = ?', whereArgs: ['QRF']);
        }
        // v18 : duree et date/heure de debut associees a chaque position.
        if (oldVersion < 18) {
          final cols = await db.rawQuery('PRAGMA table_info(personnel)');
          final noms = cols.map((c) => c['name']).toSet();
          if (!noms.contains('position_debut')) {
            await db.execute(
                'ALTER TABLE personnel ADD COLUMN position_debut TEXT');
          }
          if (!noms.contains('position_duree')) {
            await db.execute(
                'ALTER TABLE personnel ADD COLUMN position_duree TEXT');
          }
        }
        // v19 : deux types d'utilisateurs (Commandant Escadron / Chef de
        // Peloton). Ajout du peloton rattache a un chef et remappage des
        // anciens roles vers les deux nouveaux.
        if (oldVersion < 19) {
          final cols = await db.rawQuery('PRAGMA table_info(utilisateur)');
          final noms = cols.map((c) => c['name']).toSet();
          if (!noms.contains('section_id')) {
            await db.execute(
                'ALTER TABLE utilisateur ADD COLUMN section_id INTEGER');
          }
          await db.update('utilisateur', {'role_code': RoleCode.cmdEscadron},
              where: "role_code IN ('ADMIN', 'CMD_UNITE', 'SECRETAIRE_RH')");
          await db.update('utilisateur', {'role_code': RoleCode.chefPeloton},
              where: "role_code IN ('ARMURIER', 'CHEF_SECTION', 'CONSULTATION')");
          await db.update('utilisateur', {'role_code': RoleCode.chefPeloton},
              where: 'role_code IS NULL OR role_code NOT IN (?, ?)',
              whereArgs: [RoleCode.cmdEscadron, RoleCode.chefPeloton]);
        }
        // v20 : etats quotidiens rattaches a un peloton (section_id) pour
        // restreindre l'onglet Etats aux chefs de peloton.
        if (oldVersion < 20) {
          final cols = await db.rawQuery('PRAGMA table_info(etat_quotidien)');
          final noms = cols.map((c) => c['name']).toSet();
          if (!noms.contains('section_id')) {
            await db.execute(
                'ALTER TABLE etat_quotidien ADD COLUMN section_id INTEGER');
          }
        }
        // v21 : QRF Intervention - grades autorises par poste (fonction) d'un
        // equipage d'engin blinde (JSON : {"CE":[1,2],"CP":[7]}).
        if (oldVersion < 21) {
          final cols = await db.rawQuery('PRAGMA table_info(service_qrf)');
          final noms = cols.map((c) => c['name']).toSet();
          if (!noms.contains('grades_fonctions')) {
            await db.execute(
                'ALTER TABLE service_qrf ADD COLUMN grades_fonctions TEXT');
          }
        }
        // v22 : autorisations accordees par le Commandant Escadron aux chefs
        // de peloton pour modifier les donnees de leur peloton.
        if (oldVersion < 22) {
          await db.execute(_sqlAutorisation);
        }
        // v23 : QRF par equipage - une seule QRF regroupe desormais plusieurs
        // equipages (nombre_equipages) ; chaque membre est rattache a son
        // equipage (equipage).
        if (oldVersion < 23) {
          final colsQrf = await db.rawQuery('PRAGMA table_info(service_qrf)');
          final nomsQrf = colsQrf.map((c) => c['name']).toSet();
          if (!nomsQrf.contains('nombre_equipages')) {
            await db.execute(
                'ALTER TABLE service_qrf ADD COLUMN nombre_equipages INTEGER DEFAULT 1');
          }
          final colsMembre =
              await db.rawQuery('PRAGMA table_info(service_qrf_membre)');
          final nomsMembre = colsMembre.map((c) => c['name']).toSet();
          if (!nomsMembre.contains('equipage')) {
            await db.execute(
                'ALTER TABLE service_qrf_membre ADD COLUMN equipage INTEGER DEFAULT 1');
          }
          // Regroupe les equipages existants (une QRF par equipage auparavant)
          // en une seule QRF multi-equipages.
          await _fusionnerQrfEquipages(db);
        }
        // v24 : affectation organique de chaque militaire a son peloton.
        // Sans cela le tableau de bord (filtre par affectation) restait a 0
        // sur une installation neuve.
        if (oldVersion < 24) {
          // Complete les pelotons manquants (4e Peloton absent des anciennes bases).
          for (final s in kSections) {
            final existe = await db.query('section',
                columns: ['id'], where: 'code = ?', whereArgs: [s[0]]);
            if (existe.isEmpty) {
              final esc = await db.query('escadron', columns: ['id'], limit: 1);
              if (esc.isNotEmpty) {
                await db.insert('section', {
                  'escadron_id': esc.first['id'],
                  'code': s[0],
                  'libelle': s[1],
                  'ordre': int.parse(s[2]),
                });
              }
            }
          }
          // Recale le peloton des comptes chef dont la section n'existait pas.
          final sectionIdParCode = <String, int>{
            for (final r in await db.query('section', columns: ['id', 'code']))
              (r['code'] as String): r['id'] as int,
          };
          for (final u in kUsers) {
            if (u.length > 4 && u[4].isNotEmpty) {
              final sid = sectionIdParCode[u[4]];
              if (sid != null) {
                await db.update('utilisateur', {'section_id': sid},
                    where: 'username = ? AND (section_id IS NULL OR section_id = 0)',
                    whereArgs: [u[0]]);
              }
            }
          }
          await _backfillAffectations(db);
        }
        // v15 : nom libre d'un service (type "Autre service").
        if (oldVersion < 15) {
          final cols = await db.rawQuery('PRAGMA table_info(service)');
          final noms = cols.map((c) => c['name']).toSet();
          if (!noms.contains('libelle')) {
            await db.execute('ALTER TABLE service ADD COLUMN libelle TEXT');
          }
        }
      },
    );
  }

  static const String _sqlPrecisionPosition =
      'CREATE TABLE IF NOT EXISTS precision_position('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'position TEXT NOT NULL, libelle TEXT NOT NULL, created_at TEXT, '
      'created_by INTEGER, UNIQUE(position, libelle))';

  static const String _sqlServicePoste =
      'CREATE TABLE IF NOT EXISTS service_poste('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, service_id INTEGER, parent_id INTEGER, '
      "libelle TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'BASIQUE', "
      'effectif_requis INTEGER, creneau_debut TEXT, creneau_fin TEXT, '
      'ordre INTEGER DEFAULT 0, observation TEXT, created_at TEXT)';

  static const String _sqlServiceRole =
      'CREATE TABLE IF NOT EXISTS service_role('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, service_id INTEGER, code TEXT, '
      'libelle TEXT NOT NULL, nombre_requis INTEGER DEFAULT 1, ordre INTEGER DEFAULT 0)';

  static const String _sqlServiceQrf =
      'CREATE TABLE IF NOT EXISTS service_qrf('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, service_id INTEGER, type TEXT, '
      "mode TEXT, engin TEXT, effectif INTEGER, ordre INTEGER, "
      'nombre_equipages INTEGER DEFAULT 1, '
      'grades_fonctions TEXT, created_at TEXT)';

  static const String _sqlServiceQrfMembre =
      'CREATE TABLE IF NOT EXISTS service_qrf_membre('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, qrf_id INTEGER, fonction TEXT, '
      'militaire_id INTEGER, equipage INTEGER DEFAULT 1, ordre INTEGER)';

  static const String _sqlServiceGradeAutorise =
      'CREATE TABLE IF NOT EXISTS service_grade_autorise('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, service_id INTEGER, '
      'cible_type TEXT NOT NULL, cible_id INTEGER NOT NULL, grade_id INTEGER NOT NULL, '
      'UNIQUE(cible_type, cible_id, grade_id))';

  static const String _sqlAutorisation =
      'CREATE TABLE IF NOT EXISTS autorisation('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, section_id INTEGER NOT NULL, '
      'code TEXT NOT NULL, accorde INTEGER NOT NULL DEFAULT 0, '
      'maj_par INTEGER, maj_le TEXT, UNIQUE(section_id, code))';

  /// Referentiel des grades par categorie statutaire (ordre croissant) :
  /// - Officiers          : Sous-Lieutenant -> Colonel major ;
  /// - Sous-officiers     : Marechal des logis -> Adjudant-chef major ;
  /// - Militaires du rang : Cavalier 2e classe -> Brigadier-chef.
  static const List<List<Object>> _kGrades = [
    // Officiers
    ['SLT', 'Sous-Lieutenant', 'OFF', 10],
    ['LTN', 'Lieutenant', 'OFF', 20],
    ['CNE', 'Capitaine', 'OFF', 30],
    ['CDT', 'Commandant', 'OFF', 40],
    ['LCL', 'Lieutenant-Colonel', 'OFF', 50],
    ['COL', 'Colonel', 'OFF', 60],
    ['COLM', 'Colonel major', 'OFF', 70],
    // Sous-officiers
    ['MDL', 'Marechal des Logis', 'S-OFF', 110],
    ['MDC', 'Marechal des Logis Chef', 'S-OFF', 120],
    ['ADT', 'Adjudant', 'S-OFF', 130],
    ['ADC', 'Adjudant-chef', 'S-OFF', 140],
    ['ACM', 'Adjudant-chef major', 'S-OFF', 150],
    // Militaires du rang
    ['CLIER2', 'Cavalier de 2e classe', 'MDR', 210],
    ['CLIER1', 'Cavalier de 1ere classe', 'MDR', 220],
    ['BIER', 'Brigadier', 'MDR', 230],
    ['BCH', 'Brigadier-chef', 'MDR', 240],
  ];

  /// Supprime les grades errones d'anciennes bases : "ADJ" (doublon de "ADT")
  /// et "MDR" (categorie de grade). Les militaires concernes sont reaffectes
  /// (ADJ -> ADT) ou laisses sans grade (MDR).
  Future<void> _supprimerGradesErrones(Database db) async {
    Future<int?> idDe(String code) async {
      final r = await db.query('grade',
          columns: ['id'], where: 'code = ?', whereArgs: [code]);
      return r.isEmpty ? null : r.first['id'] as int;
    }

    final adt = await idDe('ADT');
    final cibles = {'ADJ': adt, 'MDR': null};
    for (final e in cibles.entries) {
      final id = await idDe(e.key);
      if (id == null) continue;
      await db.update('personnel', {'grade_id': e.value},
          where: 'grade_id = ?', whereArgs: [id]);
      await db.delete('service_grade_autorise',
          where: 'grade_id = ?', whereArgs: [id]);
      await db.delete('grade', where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Fusionne les QRF par equipage d'une meme astreinte (meme service, type et
  /// engin) en une seule QRF multi-equipages : les membres des lignes suivantes
  /// sont rattaches a la premiere avec leur numero d'equipage, puis les lignes
  /// en trop sont supprimees.
  Future<void> _fusionnerQrfEquipages(Database db) async {
    final rows = await db.query('service_qrf',
        where: 'mode = ?',
        whereArgs: ['EQUIPAGE'],
        orderBy: 'service_id ASC, ordre ASC, id ASC');
    final groupes = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      final key = '${r['service_id']}|${r['type']}|${r['engin']}';
      groupes.putIfAbsent(key, () => []).add(r);
    }
    for (final groupe in groupes.values) {
      if (groupe.length <= 1) continue;
      final master = groupe.first;
      final masterId = master['id'] as int;
      var grades = (master['grades_fonctions'] as String?) ?? '';
      for (var i = 1; i < groupe.length; i++) {
        final q = groupe[i];
        final qid = q['id'] as int;
        if (grades.trim().isEmpty) {
          grades = (q['grades_fonctions'] as String?) ?? '';
        }
        await db.update(
            'service_qrf_membre', {'qrf_id': masterId, 'equipage': i + 1},
            where: 'qrf_id = ?', whereArgs: [qid]);
        await db.delete('service_qrf', where: 'id = ?', whereArgs: [qid]);
      }
      await db.update(
          'service_qrf',
          {'nombre_equipages': groupe.length, 'grades_fonctions': grades},
          where: 'id = ?',
          whereArgs: [masterId]);
    }
  }

  /// Insere les grades manquants et met a jour libelle / categorie / ordre
  /// (utilise au seed initial et a la migration v11).
  Future<void> _majGrades(Database db) async {
    final catIds = await _idMap(db, 'categorie');
    for (final g in _kGrades) {
      final code = g[0] as String;
      final values = <String, Object?>{
        'libelle': g[1],
        'categorie_id': catIds[g[2]],
        'ordre': g[3],
      };
      final maj = await db.update('grade', values,
          where: 'code = ?', whereArgs: [code]);
      if (maj == 0) {
        await db.insert('grade', {'code': code, ...values});
      }
    }
  }

  /// Dossier ou stocker le fichier de base de donnees selon la plateforme.
  Future<String> _dossierBase() async {
    const dirOverride = String.fromEnvironment('GPM_DB_DIR');
    if (dirOverride.isNotEmpty) {
      final d = Directory(dirOverride);
      await d.create(recursive: true);
      return d.path;
    }
    if (Platform.isWindows || Platform.isLinux) {
      final dossier = await getApplicationSupportDirectory();
      await Directory(dossier.path).create(recursive: true);
      return dossier.path;
    }
    return getDatabasesPath();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Chemin du fichier de base de donnees sur le disque.
  Future<String> get chemin async => p.join(await _dossierBase(), _dbName);

  /// Remplace la base courante par le fichier [source] (import de sauvegarde).
  ///
  /// La base actuelle est conservee sous `<base>.avant_import`. Les fichiers
  /// journaliers (`-wal`, `-shm`, `-journal`) sont supprimes pour eviter tout
  /// residu. La base est rouverte automatiquement au prochain acces.
  Future<void> remplacerPar(File source) async {
    await close();
    final target = await chemin;
    final cible = File(target);
    if (await cible.exists()) {
      await cible.copy('$target.avant_import');
    }
    for (final suffixe in const ['-wal', '-shm', '-journal']) {
      final residu = File('$target$suffixe');
      if (await residu.exists()) await residu.delete();
    }
    await source.copy(target);
    for (final suffixe in const ['-wal', '-shm', '-journal']) {
      final residu = File('$target$suffixe');
      if (await residu.exists()) await residu.delete();
    }
    _db = null;
  }

  // ---------------------------------------------------------------------------
  // Schema
  // ---------------------------------------------------------------------------
  Future<void> _createSchema(Database db) async {
    const statements = <String>[
      'CREATE TABLE categorie(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE, libelle TEXT)',
      'CREATE TABLE grade(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE, libelle TEXT, categorie_id INTEGER, ordre INTEGER)',
      'CREATE TABLE groupe_sanguin(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE)',
      'CREATE TABLE domaine(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE, libelle TEXT)',
      'CREATE TABLE situation_matrimoniale(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE, libelle TEXT)',
      'CREATE TABLE statut(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE, libelle TEXT, libelle_rapport TEXT, disponible INTEGER, ordre_rapport INTEGER)',
      'CREATE TABLE escadron(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE, libelle TEXT, localisation TEXT)',
      'CREATE TABLE section(id INTEGER PRIMARY KEY AUTOINCREMENT, escadron_id INTEGER, code TEXT, libelle TEXT, ordre INTEGER)',
      'CREATE TABLE groupe(id INTEGER PRIMARY KEY AUTOINCREMENT, section_id INTEGER, code TEXT, libelle TEXT)',
      'CREATE TABLE equipe(id INTEGER PRIMARY KEY AUTOINCREMENT, groupe_id INTEGER, code TEXT, libelle TEXT)',
      'CREATE TABLE fonction(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE, libelle TEXT)',
      '''CREATE TABLE personnel(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_id INTEGER, nom_prenoms TEXT NOT NULL, matricule TEXT, mecano TEXT,
        escadron_id INTEGER, position TEXT, position_precision TEXT,
        position_debut TEXT, position_duree TEXT,
        date_naissance TEXT, lieu_naissance TEXT,
        nom_pere TEXT, nom_mere TEXT, categorie_id INTEGER, genre TEXT,
        situation_matrimoniale_id INTEGER, date_debut_service TEXT, date_nomination TEXT,
        reference_nomination TEXT, date_arrivee_corps TEXT, date_effet TEXT,
        unite_provenance TEXT, reference_affectation TEXT, date_affectation TEXT,
        nouvelle_unite_affectation TEXT, reference TEXT, domaine_id INTEGER,
        diplome_militaire TEXT, decision TEXT, diplome_civil TEXT, niveau_etude TEXT,
        nom_conjoint TEXT, nombre_enfants INTEGER, personne_appeler TEXT, telephone TEXT,
        numero_cim TEXT, cni TEXT, nni TEXT, passeport TEXT, mugfci TEXT, fpm TEXT, cmu TEXT,
        groupe_sanguin_id INTEGER, lieu_habitation TEXT, livret_matricule TEXT,
        dossier_pension TEXT, droit_dossier_pension TEXT, situation_dossier TEXT,
        promotion_classe TEXT, taille REAL, actif INTEGER DEFAULT 1,
        created_at TEXT, updated_at TEXT, created_by INTEGER, updated_by INTEGER)''',
      'CREATE TABLE affectation_organique(id INTEGER PRIMARY KEY AUTOINCREMENT, militaire_id INTEGER, section_id INTEGER, groupe_id INTEGER, equipe_id INTEGER, fonction_id INTEGER, date_debut TEXT, date_fin TEXT, actif INTEGER DEFAULT 1)',
      'CREATE TABLE situation(id INTEGER PRIMARY KEY AUTOINCREMENT, militaire_id INTEGER, statut_id INTEGER, date_debut TEXT, date_fin TEXT, motif TEXT, reference TEXT, lieu TEXT, created_by INTEGER, created_at TEXT)',
      _sqlPrecisionPosition,
      'CREATE TABLE type_service(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE, libelle TEXT, effectif_requis INTEGER)',
      'CREATE TABLE poste(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT, libelle TEXT, escadron_id INTEGER)',
      'CREATE TABLE service(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, '
      'creneau_debut TEXT, creneau_fin TEXT, duree_heures INTEGER DEFAULT 24, '
      'date_fin TEXT, type_service_id INTEGER, libelle TEXT, poste_id INTEGER, '
      'statut TEXT, origine TEXT, created_by INTEGER, created_at TEXT)',
      'CREATE TABLE service_affectation(id INTEGER PRIMARY KEY AUTOINCREMENT, service_id INTEGER, militaire_id INTEGER, role_service TEXT, present INTEGER, observation TEXT, service_poste_id INTEGER, service_role_id INTEGER)',
      _sqlServicePoste,
      _sqlServiceRole,
      _sqlServiceQrf,
      _sqlServiceQrfMembre,
      _sqlServiceGradeAutorise,
      _sqlAutorisation,
      // Tables armement desactivees
      // 'CREATE TABLE type_arme(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT UNIQUE, libelle TEXT, calibre TEXT)',
      // 'CREATE TABLE arme(id INTEGER PRIMARY KEY AUTOINCREMENT, numero_serie TEXT UNIQUE, type_arme_id INTEGER, marque TEXT, etat TEXT, localisation TEXT, created_at TEXT, updated_at TEXT)',
      // 'CREATE TABLE dotation(id INTEGER PRIMARY KEY AUTOINCREMENT, militaire_id INTEGER, arme_id INTEGER, date_dotation TEXT, date_retour TEXT, type_usage TEXT, etat_depart TEXT, etat_retour TEXT, observation TEXT, created_by INTEGER)',
      // 'CREATE TABLE munition(id INTEGER PRIMARY KEY AUTOINCREMENT, type_calibre TEXT, designation TEXT, stock_actuel INTEGER, seuil_alerte INTEGER, unite TEXT)',
      // 'CREATE TABLE mouvement_armurerie(id INTEGER PRIMARY KEY AUTOINCREMENT, sens TEXT, arme_id INTEGER, munition_id INTEGER, quantite INTEGER, date_heure TEXT, motif TEXT, reference_ordre TEXT, beneficiaire_id INTEGER, armurier_id INTEGER, statut_validation TEXT, valide_par INTEGER, created_at TEXT)',
      'CREATE TABLE etat_quotidien(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, type TEXT, section_id INTEGER, effectif_total INTEGER, total_mission INTEGER, total_stage INTEGER, total_mise_a_disposition INTEGER, total_permission INTEGER, total_malades INTEGER, total_repos_medical INTEGER, total_absent INTEGER, total_indisponible INTEGER, total_disponible INTEGER, contenu_json TEXT, genere_par INTEGER, created_at TEXT)',
      'CREATE TABLE utilisateur(id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE, nom_complet TEXT, mot_de_passe_hash TEXT, role_code TEXT, militaire_id INTEGER, section_id INTEGER, actif INTEGER DEFAULT 1, derniere_connexion TEXT, created_at TEXT)',
      'CREATE TABLE journal_audit(id INTEGER PRIMARY KEY AUTOINCREMENT, utilisateur_id INTEGER, utilisateur_nom TEXT, action TEXT, entite TEXT, entite_id TEXT, valeur_avant TEXT, valeur_apres TEXT, date_heure TEXT, hash_precedent TEXT, hash_courant TEXT)',
      'CREATE TABLE sync_outbox(id INTEGER PRIMARY KEY AUTOINCREMENT, entite TEXT, entite_id TEXT, action TEXT, payload TEXT, date_heure TEXT, synchronise INTEGER DEFAULT 0)',
      'CREATE INDEX idx_personnel_nom ON personnel(nom_prenoms)',
      'CREATE INDEX idx_personnel_matricule ON personnel(matricule)',
      'CREATE INDEX idx_affectation_militaire ON affectation_organique(militaire_id, actif)',
      'CREATE INDEX idx_situation_militair ON situation(militaire_id, date_debut)',
      'CREATE INDEX idx_service_poste ON service_poste(service_id, parent_id)',
    ];
    for (final s in statements) {
      await db.execute(s);
    }
  }

  // ---------------------------------------------------------------------------
  // Affectation organique (rattachement de chaque militaire a un peloton)
  // ---------------------------------------------------------------------------
  Future<void> _backfillAffectations(Database db) async {
    final sectionIdParCode = <String, int>{
      for (final row in await db.query('section', columns: ['id', 'code']))
        (row['code'] as String): row['id'] as int,
    };
    final dejaAssignes = <int>{
      for (final row in await db.query('affectation_organique',
          columns: ['militaire_id'], where: 'actif = 1'))
        (row['militaire_id'] as int),
    };
    final now = DateTime.now().toIso8601String();
    for (final p in await db.query('personnel', columns: ['id', 'matricule'])) {
      final id = p['id'] as int;
      if (dejaAssignes.contains(id)) continue;
      final code = kSeedAffectations[(p['matricule'] as String?) ?? ''];
      final sectionId = code == null ? null : sectionIdParCode[code];
      if (sectionId == null) continue;
      await db.insert('affectation_organique', {
        'militaire_id': id,
        'section_id': sectionId,
        'date_debut': now,
        'actif': 1,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Seed
  // ---------------------------------------------------------------------------
  Future<void> _seed(Database db) async {
    final now = DateTime.now().toIso8601String();

    await db.insert('categorie', {'code': 'OFF', 'libelle': 'Officier'});
    await db.insert('categorie', {'code': 'S-OFF', 'libelle': 'Sous-officier'});
    await db.insert('categorie', {'code': 'MDR', 'libelle': 'Militaire du rang'});
    final catIds = await _idMap(db, 'categorie');

    await _majGrades(db);
    final gradeIds = await _idMap(db, 'grade');

    for (final gs in ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-']) {
      await db.insert('groupe_sanguin', {'code': gs});
    }

    final domaines = <String>{
      'INFANTERIE', 'BLINDE', 'GENIE', 'TRANSMISSION', 'ADMINISTRATION',
      for (final p in kSeedPersonnel)
        if ((p['domaine'] ?? '').trim().isNotEmpty) p['domaine']!.trim(),
    };
    for (final d in domaines) {
      await db.insert('domaine', {'code': d, 'libelle': d});
    }
    final domaineIds = await _idMap(db, 'domaine');

    await db.insert('situation_matrimoniale', {'code': 'CELIBATAIRE', 'libelle': 'Celibataire'});
    await db.insert('situation_matrimoniale', {'code': 'MARIE', 'libelle': 'Marie(e)'});
    await db.insert('situation_matrimoniale', {'code': 'DIVORCE', 'libelle': 'Divorce(e)'});
    await db.insert('situation_matrimoniale', {'code': 'VEUF', 'libelle': 'Veuf(ve)'});
    final sitMatIds = await _idMap(db, 'situation_matrimoniale');

    for (final s in kStatuts) {
      await db.insert('statut', {
        'code': s[0],
        'libelle': s[1],
        'libelle_rapport': s[2],
        'disponible': int.parse(s[3]),
        'ordre_rapport': int.parse(s[4]),
      });
    }
    final statutIds = await _idMap(db, 'statut');

    final escadronId = await db.insert('escadron', {
      'code': '2EBC',
      'libelle': '2e Escadron Blinde de Combat',
      'localisation': 'Akouedo',
    });

    for (final s in kSections) {
      await db.insert('section', {
        'escadron_id': escadronId,
        'code': s[0],
        'libelle': s[1],
        'ordre': int.parse(s[2]),
      });
    }

    for (final f in kFonctions) {
      await db.insert('fonction', {'code': f[0], 'libelle': f[1]});
    }

    for (final t in [
      ['ASTREINTE', 'Astreinte', 3],
      ['AUTRE', 'Autre service', 0],
    ]) {
      await db.insert('type_service', {
        'code': t[0],
        'libelle': t[1],
        'effectif_requis': t[2],
      });
    }
    final typeServiceIds = await _idMap(db, 'type_service');

    final posteIds = <String, int>{};
    for (final po in [
      ['PORTE_PRINCIPALE', 'Porte principale'],
      ['POSTE_GARDE', 'Poste de garde'],
      ['MAGASIN', 'Magasin'],
      ['PC', 'Poste de commandement'],
      ['ARSENAL', 'Arsenal'],
    ]) {
      posteIds[po[0]] = await db.insert('poste', {
        'code': po[0],
        'libelle': po[1],
        'escadron_id': escadronId,
      });
    }

    // Personnel : donnees reelles du fichier principal BASE DE DONNEES 2eEBC.
    final gsIds = await _idMap(db, 'groupe_sanguin');
    for (final row in kSeedPersonnel) {
      final gradeCode = row['grade'] ?? '';
      final catCode = _normaliserCategorie(row['categorie'] ?? '');
      final gsCode = _normaliserGroupeSanguin(row['groupeSanguin'] ?? '');
      final sitMatCode = (row['situationMatrimoniale'] ?? '').trim();
      final domaineCode = (row['domaine'] ?? '').trim();
      final statutCode = statutCodeDepuisPosition(row['position']);

      final pid = await db.insert('personnel', {
        'grade_id': gradeIds[gradeCode],
        'nom_prenoms': row['nom'] ?? '',
        'matricule': row['matricule'],
        'mecano': row['mecano'],
        'escadron_id': escadronId,
        'position': positionDepuisStatutCode(statutCode),
        'date_naissance': row['dateNaissance'],
        'lieu_naissance': row['lieuNaissance'],
        'nom_pere': row['nomPere'],
        'nom_mere': row['nomMere'],
        'categorie_id': catIds[catCode],
        'genre': row['genre'],
        'situation_matrimoniale_id': sitMatIds[sitMatCode],
        'date_debut_service': row['dateDebutService'],
        'date_nomination': row['dateNomination'],
        'reference_nomination': row['referenceNomination'],
        'date_arrivee_corps': row['dateArriveeCorps'],
        'date_effet': row['dateEffet'],
        'unite_provenance': row['uniteProvenance'],
        'reference_affectation': row['referenceAffectation'],
        'date_affectation': row['dateAffectation'],
        'nouvelle_unite_affectation': row['nouvelleUniteAffectation'],
        'reference': row['reference'],
        'domaine_id': domaineIds[domaineCode],
        'diplome_militaire': row['diplomeMilitaire'],
        'decision': row['decision'],
        'diplome_civil': row['diplomeCivil'],
        'niveau_etude': row['niveauEtude'],
        'nom_conjoint': row['nomConjoint'],
        'nombre_enfants': int.tryParse(row['nombreEnfants'] ?? ''),
        'personne_appeler': row['personneAppeler'],
        'telephone': row['telephone'],
        'numero_cim': row['numeroCim'],
        'cni': row['cni'],
        'nni': row['nni'],
        'passeport': row['passeport'],
        'mugfci': row['mugfci'],
        'fpm': row['fpm'],
        'cmu': row['cmu'],
        'groupe_sanguin_id': gsIds[gsCode],
        'lieu_habitation': row['lieuHabitation'],
        'livret_matricule': row['livretMatricule'],
        'dossier_pension': row['dossierPension'],
        'droit_dossier_pension': row['droitDossierPension'],
        'situation_dossier': row['situationDossier'],
        'promotion_classe': row['promotionClasse'],
        'taille': _parseTaille(row['taille']),
        'actif': 1,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert('situation', {
        'militaire_id': pid,
        'statut_id': statutIds[statutCode],
        'date_debut': now,
        'created_at': now,
      });
    }

    // Affectation organique : chaque militaire rattache a son peloton/section.
    await _backfillAffectations(db);

    // Precisions de position par defaut (extensibles via "AJOUTER").
    await _seedPrecisions(db, now);

        // Armement desactive

    // Utilisateurs
    final sectionIdParCode = <String, int>{
      for (final row in await db.query('section', columns: ['id', 'code']))
        (row['code'] as String): row['id'] as int,
    };
    for (final u in kUsers) {
      await db.insert('utilisateur', {
        'username': u[0],
        'nom_complet': u[1],
        'mot_de_passe_hash': hasherMotDePasse(u[2]),
        'role_code': u[3],
        'section_id': u.length > 4 ? sectionIdParCode[u[4]] : null,
        'actif': 1,
        'created_at': now,
      });
    }

    // Service du jour (garde) affecte a 8 militaires disponibles
    final dispo = await db.query(
      'personnel',
      where: 'id IN (SELECT militaire_id FROM situation s '
          'JOIN statut st ON st.id = s.statut_id '
          'WHERE st.disponible = 1 AND s.date_fin IS NULL)',
      limit: 8,
    );
    if (dispo.isNotEmpty) {
      final serviceId = await db.insert('service', {
        'date': _today(),
        'creneau_debut': '06:00',
        'creneau_fin': '18:00',
        'type_service_id': typeServiceIds['AUTRE'],
        'poste_id': posteIds['POSTE_GARDE'],
        'statut': 'PLANIFIE',
        'origine': 'MANUEL',
        'created_at': now,
      });
      var i = 0;
      for (final m in dispo) {
        await db.insert('service_affectation', {
          'service_id': serviceId,
          'militaire_id': m['id'],
          'role_service': i == 0 ? 'CHEF_POSTE' : 'SENTINELLE',
          'present': 1,
        });
        i++;
      }
    }
  }

  static String _normaliserCategorie(String brut) {
    final v = brut.trim().toUpperCase().replaceAll('/', '-');
    if (v == 'OFF' || v == 'S-OFF' || v == 'MDR') return v;
    if (v.contains('OFF')) return v.startsWith('S') ? 'S-OFF' : 'OFF';
    return 'MDR';
  }

  static String _normaliserGroupeSanguin(String brut) {
    return brut.trim().toUpperCase().replaceAll('0', 'O');
  }

  static double? _parseTaille(String? brut) {
    if (brut == null || brut.trim().isEmpty) return null;
    return double.tryParse(brut.trim().replaceAll(',', '.'));
  }

  static String _today() {
    final d = DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<Map<String, int>> _idMap(Database db, String table) async {
    final rows = await db.query(table, columns: ['id', 'code']);
    final map = <String, int>{};
    for (final r in rows) {
      final code = r['code'] as String?;
      if (code != null) map[code] = r['id'] as int;
    }
    return map;
  }

  /// Insere les precisions de position par defaut (reutilisables et
  /// extensibles par l'utilisateur via "AJOUTER").
  Future<void> _seedPrecisions(Database db, String now) async {
    for (final entry in kPositionPrecisions.entries) {
      for (final libelle in entry.value) {
        await db.insert(
          'precision_position',
          {'position': entry.key, 'libelle': libelle, 'created_at': now},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }
}

/// Hachage SHA-256 du mot de passe (demonstration, remplace par bcrypt/argon2
/// en production avec sel aleatoire).
String hasherMotDePasse(String clair) {
  return sha256.convert(clair.codeUnits).toString();
}
