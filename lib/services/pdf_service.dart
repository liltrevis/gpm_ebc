import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/colonnes_etat.dart';
import '../core/constants.dart';
import '../models/dashboard_stats.dart';
import '../models/personnel.dart';
import '../models/service.dart';
import '../models/spa.dart';
import '../core/format.dart';

/// Generation et partage de documents PDF.
class PdfService {
  static const String _unite = '2e ESCADRON BLINDE DE COMBAT';

  static pw.MemoryImage? _logo;
  static bool _logoTente = false;

  /// Charge (une seule fois) le logo de l'escadron depuis les assets.
  static Future<void> _preparerLogo() async {
    if (_logoTente) return;
    _logoTente = true;
    try {
      final data = await rootBundle.load(AppImages.logo);
      _logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      _logo = null;
    }
  }

  /// En-tete commun avec logo optionnel + titres.
  static pw.Header _entete({
    String? titre,
    String? sousTitre,
    double tailleUnite = 14,
    bool effectifs = false,
  }) {
    final textes = <pw.Widget>[
      pw.Text(effectifs ? '$_unite - EFFECTIFS' : _unite,
          style: pw.TextStyle(
              fontSize: tailleUnite, fontWeight: pw.FontWeight.bold)),
      if (titre != null) ...[
        pw.SizedBox(height: 2),
        pw.Text(titre, style: const pw.TextStyle(fontSize: 12)),
      ],
      if (sousTitre != null) ...[
        pw.SizedBox(height: 2),
        pw.Text(sousTitre, style: const pw.TextStyle(fontSize: 10)),
      ],
    ];
    final colonne = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: textes,
    );
    final logo = _logo;
    return pw.Header(
      level: 0,
      child: logo == null
          ? colonne
          : pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(logo, width: 44, height: 44),
                pw.SizedBox(width: 10),
                pw.Expanded(child: colonne),
              ],
            ),
    );
  }

  static Future<Uint8List> etatQuotidien(
    DashboardStats s, {
    String? date,
    required Map<String, int> parStatut,
  }) async {
    await _preparerLogo();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(
          tailleUnite: 16,
          sousTitre:
              'Situation de prise d\'armes du ${afficherDateFr(date ?? aujourdHui())}',
        ),
        pw.SizedBox(height: 8),
        pw.Text('Effectif et disponibilite',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Table.fromTextArray(
          context: ctx,
          headers: ['Rubrique', 'Effectif'],
          data: [
            ['Effectif total', '${s.effectifTotal}'],
            ['Disponible', '${s.disponible}'],
            ['Indisponible', '${s.indisponible}'],
            ['En mission', '${s.mission}'],
            ['En stage', '${s.stage}'],
            ['Mise a disposition', '${s.miseADisposition}'],
            ['Permission / conge', '${s.permission}'],
            ['Malades', '${s.malades}'],
            ['Repos medical', '${s.reposMedical}'],
            ['Absents', '${s.absent}'],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 12),
        pw.Text('Repartition par peloton',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Table.fromTextArray(
          context: ctx,
          headers: ['Peloton', 'Effectif', 'Disponible'],
          data: s.parSection
              .map((e) => [e.libelle, '${e.effectif}', '${e.disponible}'])
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 12),
        pw.Text('Detail par statut',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Table.fromTextArray(
          context: ctx,
          headers: ['Statut', 'Effectif'],
          data: parStatut.entries.map((e) => [e.key, '${e.value}']).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 16),
        pw.Text('Etat du parc d\'armement',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Table.fromTextArray(
          context: ctx,
          headers: ['Indicateur', 'Valeur'],
          data: [
            ['Armes en parc', '${s.armesTotal}'],
            ['Armes en service', '${s.armesEnService}'],
            ['Armes hors service', '${s.armesDefectueuses}'],
            ['Armes dotees', '${s.armesDotees}'],
            ['Munitions en alerte', '${s.munitionsAlerte}'],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 24),
        pw.Text('Genere le ${formatDateHeureFr(DateTime.now().toIso8601String())}'),
      ],
    ));
    return doc.save();
  }

  static Future<Uint8List> listePersonnel(List<Personnel> personnel) async {
    await _preparerLogo();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(effectifs: true, tailleUnite: 15),
        pw.Table.fromTextArray(
          context: ctx,
          headers: ['Grade', 'Nom et prenoms', 'Matricule', 'Peloton', 'Statut'],
          data: personnel
              .map((p) => [
                    p.gradeCode ?? p.gradeLibelle ?? '',
                    p.nomPrenoms,
                    p.matricule ?? '',
                    p.sectionLibelle ?? '',
                    p.statutLibelle ?? '',
                  ])
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        ),
      ],
    ));
    return doc.save();
  }

  /// Export d'un etat (liste nommee) avec les colonnes selectionnees.
  static Future<Uint8List> etatListe(
    String titre, {
    String? sousTitre,
    required List<Map<String, Object?>> concernes,
    required List<ColonneEtat> colonnes,
  }) async {
    await _preparerLogo();
    final doc = pw.Document();
    final taille = colonnes.length > 8
        ? 6.0
        : colonnes.length > 5
            ? 7.0
            : 9.0;
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        _entete(titre: titre, sousTitre: sousTitre, tailleUnite: 14),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          context: ctx,
          headers: [for (final c in colonnes) c.libelle],
          data: [
            for (final e in concernes)
              [for (final c in colonnes) c.valeur(e)],
          ],
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: taille),
          cellStyle: pw.TextStyle(fontSize: taille),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 16),
        pw.Text('Genere le ${formatDateHeureFr(DateTime.now().toIso8601String())}'),
      ],
    ));
    return doc.save();
  }

  /// Document SPA (Situation des Personnels Absents) : tableau des effectifs
  /// par categorie statutaire avec liste nominative des absents (OBS).
  static Future<Uint8List> spa(SpaData data) async {
    await _preparerLogo();
    final doc = pw.Document();
    final logo = _logo;

    final entete = <pw.Widget>[
      if (logo != null) ...[
        pw.Image(logo, width: 46, height: 46),
        pw.SizedBox(height: 4),
      ],
      pw.Text('SPA',
          style: pw.TextStyle(
              fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.Text(data.unite,
          style: pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.Text(data.dateSituation, style: const pw.TextStyle(fontSize: 11)),
    ];

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: entete,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
          columnWidths: const {
            0: pw.FlexColumnWidth(3.0),
            1: pw.FlexColumnWidth(1.0),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(1.3),
            4: pw.FlexColumnWidth(0.9),
            5: pw.FlexColumnWidth(4.0),
          },
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _spaCell('Rubrique', bold: true, align: pw.TextAlign.left, bg: PdfColors.grey300),
                _spaCell('X', bold: true, align: pw.TextAlign.center, bg: PdfColors.grey300),
                _spaCell('Y', bold: true, align: pw.TextAlign.center, bg: PdfColors.grey300),
                _spaCell('Z', bold: true, align: pw.TextAlign.center, bg: PdfColors.grey300),
                _spaCell('TOTAL', bold: true, align: pw.TextAlign.center, bg: PdfColors.grey300),
                _spaCell('OBS', bold: true, align: pw.TextAlign.left, bg: PdfColors.grey300),
              ],
            ),
            for (final bloc in data.blocs) _spaBlocRow(bloc),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('Genere le ${formatDateHeureFr(DateTime.now().toIso8601String())}',
            style: const pw.TextStyle(fontSize: 9)),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _spaCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? bg,
  }) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Ligne de tableau pour un bloc SPA : la position puis ses precisions,
  /// imbriquees dans la meme cellule (une ligne de texte par precision).
  static pw.TableRow _spaBlocRow(SpaBloc bloc) {
    final principal = bloc.ligne;
    final estSous = principal.type == SpaType.sousRubrique;
    final bg = estSous ? null : PdfColors.grey200;
    final gras = !estSous;
    return pw.TableRow(
      decoration: bg == null ? null : pw.BoxDecoration(color: bg),
      children: [
        _spaCellule(
          [
            principal.libelle,
            for (final p in bloc.precisions) '     ${p.libelle}',
          ],
          premierGras: gras,
          bg: bg,
        ),
        _spaCellule(bloc.valeursColonne((r) => '${r.officiers}'),
            align: pw.TextAlign.center, premierGras: gras, bg: bg),
        _spaCellule(bloc.valeursColonne((r) => '${r.sousOfficiers}'),
            align: pw.TextAlign.center, premierGras: gras, bg: bg),
        _spaCellule(bloc.valeursColonne((r) => '${r.hommesDuRang}'),
            align: pw.TextAlign.center, premierGras: gras, bg: bg),
        _spaCellule(bloc.valeursColonne((r) => '${r.total}'),
            align: pw.TextAlign.center, premierGras: true, bg: bg),
        _spaCellule(bloc.valeursColonne((r) => r.observation), bg: bg),
      ],
    );
  }

  /// Cellule SPA multi-lignes (position + precisions imbriquees).
  static pw.Widget _spaCellule(
    List<String> lignes, {
    pw.TextAlign align = pw.TextAlign.left,
    bool premierGras = false,
    PdfColor? bg,
  }) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Column(
        crossAxisAlignment: align == pw.TextAlign.center
            ? pw.CrossAxisAlignment.center
            : pw.CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lignes.length; i++)
            pw.Text(
              lignes[i],
              textAlign: align,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: i == 0 && premierGras
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }

  /// Document de composition d'un service / de l'astreinte : rôles dédiés
  /// puis postes principaux (chef, adjoint, postes basiques garnis par la
  /// faction).
  static Future<Uint8List> astreinte(AstreinteData data) async {
    await _preparerLogo();
    final doc = pw.Document();
    final logo = _logo;
    final lignes = data.lignes();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.Image(logo, width: 46, height: 46),
                pw.SizedBox(height: 4),
              ],
              pw.Text(data.titreDocument,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(data.service.typeLibelle ?? 'Service',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  '${afficherDateFr(data.service.date)}  '
                  '${data.service.creneauDebut ?? ''}-${data.service.creneauFin ?? ''}',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          context: ctx,
          headers: ['Rubrique / Poste', 'Effectif', 'Personnel / Détail'],
          data: lignes.map((r) => [r[0], r[1], r[2]]).toList(),
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(4),
          },
        ),
        pw.SizedBox(height: 16),
        pw.Text('Genere le ${formatDateHeureFr(DateTime.now().toIso8601String())}',
            style: const pw.TextStyle(fontSize: 9)),
      ],
    ));
    return doc.save();
  }

  static Future<void> partager(Uint8List bytes, String nomFichier) {
    return Printing.sharePdf(bytes: bytes, filename: nomFichier);
  }

  static Future<void> imprimer(Uint8List bytes, String nomFichier) {
    return Printing.layoutPdf(
      name: nomFichier,
      onLayout: (format) async => bytes,
    );
  }
}
