import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/colonnes_etat.dart';
import '../core/constants.dart';
import '../models/dashboard_stats.dart';
import '../models/personnel.dart';
import '../models/service.dart';
import '../models/spa.dart';
import '../core/format.dart';
import 'ooxml_logo.dart';

/// Generation de classeurs Excel.
class ExcelService {
  static Uint8List? _logo;
  static bool _logoTente = false;

  static Future<Uint8List?> _logoBytes() async {
    if (_logoTente) return _logo;
    _logoTente = true;
    try {
      final data = await rootBundle.load(AppImages.logo);
      _logo = data.buffer.asUint8List();
    } catch (_) {
      _logo = null;
    }
    return _logo;
  }
  static Future<String> etatQuotidien(
    DashboardStats s, {
    required Map<String, int> parStatut,
    String? date,
  }) async {
    final excel = Excel.createExcel();
    final synthese = excel['Synthese'];
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    synthese.appendRow([TextCellValue('2e ESCADRON BLINDE DE COMBAT')]);
    synthese.appendRow([
      TextCellValue('Situation du ${afficherDateFr(date ?? aujourdHui())}'),
    ]);
    synthese.appendRow([]);
    synthese.appendRow([TextCellValue('Rubrique'), TextCellValue('Effectif')]);
    void ligne(String libelle, int valeur) {
      synthese.appendRow([TextCellValue(libelle), IntCellValue(valeur)]);
    }

    ligne('Effectif total', s.effectifTotal);
    ligne('Disponible', s.disponible);
    ligne('Indisponible', s.indisponible);
    ligne('En mission', s.mission);
    ligne('En stage', s.stage);
    ligne('Mise a disposition', s.miseADisposition);
    ligne('Permission / conge', s.permission);
    ligne('Malades', s.malades);
    ligne('Repos medical', s.reposMedical);
    ligne('Absents', s.absent);

    final nbSynthese = 10;
    _styliserTitres(synthese, nbColonnes: 2);
    _styliserTableau(
      synthese,
      ligneEntete: 2,
      nbColonnes: 2,
      nbLignesDonnees: nbSynthese,
      largeurs: [26, 12],
    );

    final sections = excel['Pelotons'];
    sections.appendRow([
      TextCellValue('Peloton'),
      TextCellValue('Effectif'),
      TextCellValue('Disponible'),
    ]);
    for (final sec in s.parSection) {
      sections.appendRow([
        TextCellValue(sec.libelle),
        IntCellValue(sec.effectif),
        IntCellValue(sec.disponible),
      ]);
    }
    _styliserTableau(
      sections,
      ligneEntete: 0,
      nbColonnes: 3,
      nbLignesDonnees: s.parSection.length,
      largeurs: [24, 12, 12],
    );

    sections.appendRow([]);
    final ligneStatut = sections.maxRows;
    sections.appendRow([TextCellValue('Statut'), TextCellValue('Effectif')]);
    for (final e in parStatut.entries) {
      sections.appendRow([TextCellValue(e.key), IntCellValue(e.value)]);
    }
    _styliserTableau(
      sections,
      ligneEntete: ligneStatut,
      nbColonnes: 2,
      nbLignesDonnees: parStatut.length,
      largeurs: [24, 12],
    );

    sections.appendRow([]);
    final ligneArmes = sections.maxRows;
    sections.appendRow([
      TextCellValue('Armes en parc'),
      IntCellValue(s.armesTotal),
    ]);
    sections.appendRow([
      TextCellValue('Armes en service'),
      IntCellValue(s.armesEnService),
    ]);
    sections.appendRow([
      TextCellValue('Armes hors service'),
      IntCellValue(s.armesDefectueuses),
    ]);
    sections.appendRow([
      TextCellValue('Armes dotees'),
      IntCellValue(s.armesDotees),
    ]);
    sections.appendRow([
      TextCellValue('Munitions en alerte'),
      IntCellValue(s.munitionsAlerte),
    ]);
    _styliserTableau(
      sections,
      ligneEntete: ligneArmes,
      nbColonnes: 2,
      nbLignesDonnees: 5,
    );

    final chemin = await _chemin('etat_quotidien_${date ?? aujourdHui()}.xlsx');
    await _ecrire(excel, path: chemin);
    return chemin;
  }

  static Future<String> listePersonnel(List<Personnel> personnel) async {
    final excel = Excel.createExcel();
    final sheet = excel['Effectifs'];
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    sheet.appendRow([
      TextCellValue('Grade'),
      TextCellValue('Nom et prenoms'),
      TextCellValue('Matricule'),
      TextCellValue('Mecano'),
      TextCellValue('Peloton'),
      TextCellValue('Statut'),
    ]);
    for (final p in personnel) {
      sheet.appendRow([
        TextCellValue(p.gradeCode ?? p.gradeLibelle ?? ''),
        TextCellValue(p.nomPrenoms),
        TextCellValue(p.matricule ?? ''),
        TextCellValue(p.mecano ?? ''),
        TextCellValue(p.sectionLibelle ?? ''),
        TextCellValue(p.statutLibelle ?? ''),
      ]);
    }
    final chemin = await _basePath('effectifs_${aujourdHui()}.xlsx');
    await _ecrire(excel, path: chemin);
    return chemin;
  }

  /// Police et mise en forme alignees sur la base de donnees de reference
  /// (BASE DE DONNEES 2eEBC) : Cambria 10, bordures fines, entete en gras
  /// centre, retour a la ligne.
  static const String _police = 'Cambria';
  static const int _taillePolice = 10;
  static const double _hauteurLigne = 24.75;

  static Border _bordFin() =>
      Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black);

  static CellStyle _styleCellule({
    required bool entete,
    HorizontalAlign align = HorizontalAlign.Center,
    VerticalAlign vertical = VerticalAlign.Center,
  }) =>
      CellStyle(
        fontFamily: _police,
        fontSize: _taillePolice,
        bold: entete,
        horizontalAlign: align,
        verticalAlign: vertical,
        textWrapping: TextWrapping.WrapText,
        leftBorder: _bordFin(),
        rightBorder: _bordFin(),
        topBorder: _bordFin(),
        bottomBorder: _bordFin(),
      );

  static CellStyle _styleTitre(int taille) => CellStyle(
        fontFamily: _police,
        fontSize: taille,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

  /// Met en forme les deux lignes de titre d'une feuille (police Cambria).
  static void _styliserTitres(Sheet sheet, {required int nbColonnes}) {
    for (var c = 0; c < nbColonnes; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = _styleTitre(12);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
          .cellStyle = _styleTitre(10);
    }
  }

  /// Applique la mise en forme (police, bordures fines, en-tete gras centre,
  /// retour a la ligne) a un tableau dont l'en-tete est [ligneEntete].
  static void _styliserTableau(
    Sheet sheet, {
    required int ligneEntete,
    required int nbColonnes,
    required int nbLignesDonnees,
    List<double>? largeurs,
  }) {
    if (largeurs != null) {
      for (var c = 0; c < nbColonnes && c < largeurs.length; c++) {
        sheet.setColumnWidth(c, largeurs[c]);
      }
    }
    sheet.setRowHeight(ligneEntete, _hauteurLigne);
    for (var c = 0; c < nbColonnes; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: ligneEntete))
          .cellStyle = _styleCellule(entete: true);
    }
    for (var r = 0; r < nbLignesDonnees; r++) {
      final rowIndex = ligneEntete + 1 + r;
      sheet.setRowHeight(rowIndex, _hauteurLigne);
      for (var c = 0; c < nbColonnes; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex))
            .cellStyle = _styleCellule(entete: false);
      }
    }
  }

  /// Export Excel d'un etat (liste nommee) avec les colonnes selectionnees.
  static Future<String> etatListe(
    String titre, {
    required List<Map<String, Object?>> concernes,
    required List<ColonneEtat> colonnes,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Etat'];
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    sheet.appendRow([TextCellValue('2e ESCADRON BLINDE DE COMBAT')]);
    sheet.appendRow([TextCellValue(titre)]);
    sheet.appendRow([]);
    sheet.appendRow([for (final c in colonnes) TextCellValue(c.libelle)]);
    for (final e in concernes) {
      sheet.appendRow([
        for (final c in colonnes)
          c.cle == 'numero'
              ? IntCellValue(int.tryParse(c.valeur(e)) ?? 0)
              : TextCellValue(c.valeur(e)),
      ]);
    }

    final nbCols = colonnes.length;
    if (nbCols > 0) {
      _styliserTitres(sheet, nbColonnes: nbCols);
      // Largeurs de colonnes adaptees au libelle.
      final largeurs = [
        for (final c in colonnes)
          (c.libelle.length * 1.3 + 4).clamp(10.0, 48.0).toDouble(),
      ];
      _styliserTableau(
        sheet,
        ligneEntete: 2,
        nbColonnes: nbCols,
        nbLignesDonnees: concernes.length,
        largeurs: largeurs,
      );
    }
    final chemin = await _basePath('etat_${_slug(titre)}_${aujourdHui()}.xlsx');
    await _ecrire(excel, path: chemin);
    return chemin;
  }

  /// Export Excel du document SPA. Les precisions d'une position sont
  /// imbriquees dans la cellule de la position (une ligne de tableau par bloc).
  static Future<String> spa(SpaData data) async {
    final excel = Excel.createExcel();
    final sheet = excel['SPA'];
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    sheet.appendRow([TextCellValue('SPA')]);
    sheet.appendRow([TextCellValue(data.unite)]);
    sheet.appendRow([TextCellValue(data.dateSituation)]);
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('Rubrique'),
      TextCellValue('X'),
      TextCellValue('Y'),
      TextCellValue('Z'),
      TextCellValue('TOTAL'),
      TextCellValue('OBS'),
    ]);

    final blocs = data.blocs;
    for (final b in blocs) {
      sheet.appendRow([
        TextCellValue(_imbriquer(b.valeursColonne((r) => r.libelle))),
        TextCellValue(b.valeursColonne((r) => '${r.officiers}').join('\n')),
        TextCellValue(b.valeursColonne((r) => '${r.sousOfficiers}').join('\n')),
        TextCellValue(b.valeursColonne((r) => '${r.hommesDuRang}').join('\n')),
        TextCellValue(b.valeursColonne((r) => '${r.total}').join('\n')),
        TextCellValue(b.valeursColonne((r) => r.observation).join('\n')),
      ]);
    }

    const ligneEntete = 3;
    _styliserTitres(sheet, nbColonnes: 6);
    _styliserTableau(
      sheet,
      ligneEntete: ligneEntete,
      nbColonnes: 6,
      nbLignesDonnees: blocs.length,
      largeurs: [30, 11, 11, 11, 11, 64],
    );
    for (var r = 0; r < blocs.length; r++) {
      final rowIndex = ligneEntete + 1 + r;
      sheet.setRowHeight(rowIndex, _hauteurLigneSpa * blocs[r].hauteur);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .cellStyle = _styleCellule(
        entete: false,
        align: HorizontalAlign.Left,
        vertical: VerticalAlign.Center,
      );
    }

    final chemin = await _basePath('spa_${aujourdHui()}.xlsx');
    await _ecrire(excel, path: chemin);
    return chemin;
  }

  /// Export Excel de la composition d'un service / de l'astreinte.
  static Future<String> astreinte(AstreinteData data) async {
    final excel = Excel.createExcel();
    final sheet = excel['Astreinte'];
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    sheet.appendRow([TextCellValue(data.titreDocument)]);
    sheet.appendRow([TextCellValue(data.service.typeLibelle ?? 'Service')]);
    sheet.appendRow([
      TextCellValue(
          '${afficherDateFr(data.service.date)}  ${data.service.creneauDebut ?? ''}-${data.service.creneauFin ?? ''}'),
    ]);
    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('Rubrique / Poste'),
      TextCellValue('Effectif'),
      TextCellValue('Personnel / Détail'),
    ]);
    final lignes = data.lignes();
    for (final l in lignes) {
      sheet.appendRow([
        TextCellValue(l[0]),
        TextCellValue(l[1]),
        TextCellValue(l[2]),
      ]);
    }

    const ligneEntete = 3;
    _styliserTitres(sheet, nbColonnes: 3);
    _styliserTableau(
      sheet,
      ligneEntete: ligneEntete,
      nbColonnes: 3,
      nbLignesDonnees: lignes.length,
      largeurs: [34, 12, 60],
    );
    final chemin = await _basePath('astreinte_${data.service.date}.xlsx');
    await _ecrire(excel, path: chemin);
    return chemin;
  }

  /// Hauteur d'une ligne de texte dans le tableau SPA (multi-lignes).
  static const double _hauteurLigneSpa = 15.0;

  /// Assemble les lignes d'une meme cellule : la 1ere (position) puis les
  /// suivantes (precisions) indentees.
  static String _imbriquer(List<String> lignes) {
    if (lignes.isEmpty) return '';
    final buffer = StringBuffer(lignes.first);
    for (final l in lignes.skip(1)) {
      buffer.write('\n    $l');
    }
    return buffer.toString();
  }

  static String _slug(String texte) {
    final sansAccent = texte
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('à', 'a')
        .replaceAll(' ', '_');
    return sansAccent.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
  }

  static Future<void> _ecrire(Excel excel, {required String path}) async {
    final bytes = excel.save();
    if (bytes == null) return;
    final logo = await _logoBytes();
    final donnees = logo == null
        ? Uint8List.fromList(bytes)
        : OoxmlLogo.injecter(Uint8List.fromList(bytes), logo);
    await File(path).writeAsBytes(donnees);
  }

  static Future<String> _basePath(String nom) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, nom);
  }

  static Future<String> _chemin(String nom) => _basePath(nom);
}
