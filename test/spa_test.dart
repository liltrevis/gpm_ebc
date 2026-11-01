import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpm_ebc/data/rapport_repository.dart';
import 'package:gpm_ebc/models/spa.dart';
import 'package:gpm_ebc/services/pdf_service.dart';
import 'package:gpm_ebc/services/word_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const SpaData _spaExemple = SpaData(
  unite: '2e ESCADRON BLINDE DE COMBAT',
  dateSituation: 'DU 15 OCTOBRE 2026 1000Z',
  rows: [
    SpaRow(
        libelle: 'Mission',
        officiers: 1,
        sousOfficiers: 1,
        type: SpaType.rubrique,
        observation: 'CNE ALPHA'),
    SpaRow(
        libelle: 'LOMO NORD',
        officiers: 1,
        type: SpaType.sousRubrique,
        observation: 'CNE ALPHA'),
    SpaRow(libelle: 'Permission', hommesDuRang: 2, type: SpaType.rubrique),
  ],
);

Future<Database> _base() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('CREATE TABLE categorie(id INTEGER PRIMARY KEY, code TEXT)');
  await db.execute('CREATE TABLE grade('
      'id INTEGER PRIMARY KEY, code TEXT, categorie_id INTEGER, ordre INTEGER)');
  await db.execute('CREATE TABLE personnel('
      'id INTEGER PRIMARY KEY, actif INTEGER, nom_prenoms TEXT, '
      'position TEXT, position_precision TEXT, grade_id INTEGER, '
      'categorie_id INTEGER)');
  await db.insert('categorie', {'id': 1, 'code': 'OFF'});
  await db.insert('categorie', {'id': 2, 'code': 'S-OFF'});
  await db.insert('categorie', {'id': 3, 'code': 'MDR'});
  await db.insert('grade',
      {'id': 1, 'code': 'CNE', 'categorie_id': 1, 'ordre': 10});
  await db.insert('grade',
      {'id': 2, 'code': 'ADJ', 'categorie_id': 2, 'ordre': 41});
  await db.insert('grade',
      {'id': 3, 'code': 'MDR', 'categorie_id': 3, 'ordre': 90});

  Future<void> ajouter(int id, String nom, String pos, int grade, int cat,
      {String? prec}) {
    return db.insert('personnel', {
      'id': id,
      'actif': 1,
      'nom_prenoms': nom,
      'position': pos,
      'position_precision': prec,
      'grade_id': grade,
      'categorie_id': cat,
    });
  }

  await ajouter(1, 'ALPHA', 'Présent', 1, 1);
  await ajouter(2, 'BRAVO', 'Mission', 2, 2, prec: 'LOMO NORD');
  await ajouter(3, 'CHARLIE', 'Mission', 3, 3, prec: 'LOMO NORD');
  await ajouter(4, 'DELTA', 'Malade', 3, 3);
  await ajouter(5, 'ECHO', 'Présent', 3, 3);
  return db;
}

SpaRow _ligne(SpaData data, String libelle) =>
    data.rows.firstWhere((r) => r.libelle.trim() == libelle);

void main() {
  test('situationSpa calcule effectifs, rubriques et totaux', () async {
    final db = await _base();
    final data = await RapportRepository(db).situationSpa();

    final theo = _ligne(data, 'EFFECTIF THEORIQUE');
    expect(theo.officiers, 1);
    expect(theo.sousOfficiers, 1);
    expect(theo.hommesDuRang, 3);
    expect(theo.total, 5);

    final mission = _ligne(data, 'Mission');
    expect(mission.type, SpaType.rubrique);
    expect(mission.officiers, 0);
    expect(mission.sousOfficiers, 1);
    expect(mission.hommesDuRang, 1);

    final lomo = _ligne(data, 'LOMO NORD');
    expect(lomo.type, SpaType.sousRubrique);
    expect(lomo.total, 2);

    final malade = _ligne(data, 'Malade');
    expect(malade.hommesDuRang, 1);

    final indispo = _ligne(data, 'TOTAL INDISPONIBLE');
    expect(indispo.officiers, 0);
    expect(indispo.sousOfficiers, 1);
    expect(indispo.hommesDuRang, 2);
    expect(indispo.total, 3);

    final dispo = _ligne(data, 'TOTAL DISPONIBLE');
    expect(dispo.officiers, 1);
    expect(dispo.hommesDuRang, 1);
    expect(dispo.total, 2);

    await db.close();
  });

  test('grouperBlocs imbrique les precisions dans leur position', () {
    final blocs = _spaExemple.blocs;
    expect(blocs.length, 2);
    expect(blocs.first.ligne.libelle, 'Mission');
    expect(blocs.first.precisions.map((p) => p.libelle), ['LOMO NORD']);
    expect(blocs.first.hauteur, 2);
    expect(blocs.last.ligne.libelle, 'Permission');
    expect(blocs.last.precisions, isEmpty);
    expect(blocs.last.hauteur, 1);

    final labels = blocs.first.valeursColonne((r) => r.libelle);
    expect(labels, ['Mission', 'LOMO NORD']);
    final totals = blocs.first.valeursColonne((r) => '${r.total}');
    expect(totals, ['2', '1']);
  });

  test('export PDF de la SPA avec precisions imbriquees', () async {
    final bytes = await PdfService.spa(_spaExemple);
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('export Word de la SPA avec precisions imbriquees', () {
    final bytes = WordService.construireBytes(_spaExemple);
    expect(bytes, isNotEmpty);
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = archive.files.firstWhere((f) => f.name == 'word/document.xml');
    final xml = utf8.decode(doc.content as List<int>);
    expect(xml, contains('Mission'));
    expect(xml, contains('LOMO NORD'));
    expect(xml, contains('Permission'));
  });
}
