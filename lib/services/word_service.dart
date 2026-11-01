import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../models/service.dart';
import '../models/spa.dart';

/// Generation de documents Word (.docx) construits en OOXML.
class WordService {
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

  /// Genere le document SPA (.docx) et retourne le chemin du fichier.
  static Future<String> spa(SpaData data) async {
    final bytes = construireBytes(data, logo: await _logoBytes());
    final dir = await getApplicationDocumentsDirectory();
    final chemin = p.join(dir.path, 'spa_${aujourdHui()}.docx');
    await File(chemin).writeAsBytes(bytes, flush: true);
    return chemin;
  }

  /// Genere la composition d'un service / de l'astreinte (.docx).
  static Future<String> astreinte(AstreinteData data) async {
    final bytes = construireAstreinteBytes(data, logo: await _logoBytes());
    final dir = await getApplicationDocumentsDirectory();
    final chemin = p.join(dir.path, 'astreinte_${data.service.date}.docx');
    await File(chemin).writeAsBytes(bytes, flush: true);
    return chemin;
  }

  // ---------------------------------------------------------------------------
  // Construction OOXML
  // ---------------------------------------------------------------------------

  /// Construit les octets du document SPA (.docx), sans acces disque.
  static Uint8List construireBytes(SpaData data, {Uint8List? logo}) {
    final avecLogo = logo != null && logo.isNotEmpty;
    return _packager(_documentXml(data, avecLogo), logo);
  }

  /// Construit les octets de la composition d'astreinte (.docx), sans disque.
  static Uint8List construireAstreinteBytes(AstreinteData data,
      {Uint8List? logo}) {
    final avecLogo = logo != null && logo.isNotEmpty;
    return _packager(_documentAstreinte(data, avecLogo), logo);
  }

  static Uint8List _packager(String document, Uint8List? logo) {
    final avecLogo = logo != null && logo.isNotEmpty;
    final archive = Archive();
    void ajouter(String nom, List<int> contenu) =>
        archive.addFile(ArchiveFile(nom, contenu.length, contenu));

    ajouter('[Content_Types].xml', utf8.encode(_contentTypes));
    ajouter('_rels/.rels', utf8.encode(_rels));
    ajouter('word/document.xml', utf8.encode(document));
    if (avecLogo) {
      ajouter('word/_rels/document.xml.rels', utf8.encode(_documentRels));
      ajouter('word/media/image1.png', logo);
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static const String _logoXml = '''
<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:drawing>
<wp:inline distT="0" distB="0" distL="0" distR="0">
<wp:extent cx="400000" cy="400000"/><wp:docPr id="1" name="Logo escadron"/>
<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
<pic:pic><pic:nvPicPr><pic:cNvPr id="1" name="image1.png"/><pic:cNvPicPr/></pic:nvPicPr>
<pic:blipFill><a:blip r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="400000" cy="400000"/></a:xfrm>
<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>
</a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>''';

  static String _documentXml(SpaData data, bool avecLogo) {
    final corps = StringBuffer();
    if (avecLogo) {
      corps.write(_logoXml);
    }
    corps.write(_p('SPA', bold: true, taille: 32, align: 'center'));
    corps.write(_p(data.unite, bold: true, taille: 22, align: 'center'));
    corps.write(_p(data.dateSituation, taille: 18, align: 'center'));
    corps.write(_p('', taille: 8));
    corps.write(_tableSpa(data.rows));
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<w:body>$corps<w:sectPr>'
        '<w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>'
        '<w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" '
        'w:header="720" w:footer="720" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';
  }

  static const int _wAstreintePoste = 4600;
  static const int _wAstreinteEffectif = 1500;
  static const int _wAstreintePersonnel = 3900;

  static String _documentAstreinte(AstreinteData data, bool avecLogo) {
    final corps = StringBuffer();
    if (avecLogo) {
      corps.write(_logoXml);
    }
    corps.write(_p(data.titreDocument, bold: true, taille: 30, align: 'center'));
    corps.write(_p(data.service.typeLibelle ?? 'Service',
        bold: true, taille: 22, align: 'center'));
    corps.write(_p(
        '${afficherDateFr(data.service.date)}  '
        '${data.service.creneauDebut ?? ''}-${data.service.creneauFin ?? ''}',
        taille: 18,
        align: 'center'));
    corps.write(_p('', taille: 8));
    corps.write(_tableLignes(data.lignes()));
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<w:body>$corps<w:sectPr>'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" '
        'w:header="720" w:footer="720" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';
  }

  /// Tableau generique (Rubrique/Poste | Effectif | Personnel) utilise pour la
  /// composition de l'astreinte. Les lignes de titre (colonnes 2 et 3 vides)
  /// sont mises en gras.
  static String _tableLignes(List<List<String>> lignes) {
    final sb = StringBuffer();
    sb.write('<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders>'
        '${_bord('top')}${_bord('left')}${_bord('bottom')}${_bord('right')}'
        '${_bord('insideH')}${_bord('insideV')}'
        '</w:tblBorders></w:tblPr><w:tblGrid>'
        '<w:gridCol w:w="$_wAstreintePoste"/>'
        '<w:gridCol w:w="$_wAstreinteEffectif"/>'
        '<w:gridCol w:w="$_wAstreintePersonnel"/></w:tblGrid>');
    sb.write(_tr([
      _tc('Rubrique / Poste', largeur: _wAstreintePoste, bold: true, fill: 'D9D9D9'),
      _tc('Effectif', largeur: _wAstreinteEffectif, bold: true, align: 'center', fill: 'D9D9D9'),
      _tc('Personnel / Détail', largeur: _wAstreintePersonnel, bold: true, fill: 'D9D9D9'),
    ]));
    for (final l in lignes) {
      final gras = l[1].isEmpty && l[2].isEmpty;
      final fill = gras ? 'F2F2F2' : null;
      sb.write(_tr([
        _tc(l[0], largeur: _wAstreintePoste, bold: gras, fill: fill),
        _tc(l[1], largeur: _wAstreinteEffectif, align: 'center', bold: gras, fill: fill),
        _tc(l[2], largeur: _wAstreintePersonnel, bold: gras, fill: fill),
      ]));
    }
    sb.write('</w:tbl>');
    return sb.toString();
  }

  static final int _wLabel = 3000;
  static final int _wOff = 1300;
  static final int _wSoff = 1500;
  static final int _wMdr = 1700;
  static final int _wTotal = 1200;
  static final int _wObs = 6100;

  static String _tableSpa(List<SpaRow> rows) {
    final sb = StringBuffer();
    sb.write('<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders>'
        '${_bord('top')}${_bord('left')}${_bord('bottom')}${_bord('right')}'
        '${_bord('insideH')}${_bord('insideV')}'
        '</w:tblBorders></w:tblPr><w:tblGrid>'
        '<w:gridCol w:w="$_wLabel"/><w:gridCol w:w="$_wOff"/>'
        '<w:gridCol w:w="$_wSoff"/><w:gridCol w:w="$_wMdr"/>'
        '<w:gridCol w:w="$_wTotal"/><w:gridCol w:w="$_wObs"/>'
        '</w:tblGrid>');

    sb.write(_tr([
      _tc('Rubrique', largeur: _wLabel, bold: true, fill: 'D9D9D9'),
      _tc('X', largeur: _wOff, bold: true, align: 'center', fill: 'D9D9D9'),
      _tc('Y', largeur: _wSoff, bold: true, align: 'center', fill: 'D9D9D9'),
      _tc('Z', largeur: _wMdr, bold: true, align: 'center', fill: 'D9D9D9'),
      _tc('TOTAL', largeur: _wTotal, bold: true, align: 'center', fill: 'D9D9D9'),
      _tc('OBS', largeur: _wObs, bold: true, fill: 'D9D9D9'),
    ]));

    final blocs = grouperBlocs(rows);
    for (final b in blocs) {
      final fill = b.ligne.type == SpaType.sousRubrique ? null : 'F2F2F2';
      sb.write(_tr([
        _tc(_imbriquer(b.valeursColonne((r) => r.libelle)),
            largeur: _wLabel, bold: true, fill: fill),
        _tc(b.valeursColonne((r) => '${r.officiers}').join('\n'),
            largeur: _wOff, align: 'center', fill: fill),
        _tc(b.valeursColonne((r) => '${r.sousOfficiers}').join('\n'),
            largeur: _wSoff, align: 'center', fill: fill),
        _tc(b.valeursColonne((r) => '${r.hommesDuRang}').join('\n'),
            largeur: _wMdr, align: 'center', fill: fill),
        _tc(b.valeursColonne((r) => '${r.total}').join('\n'),
            largeur: _wTotal, align: 'center', bold: true, fill: fill),
        _tc(b.valeursColonne((r) => r.observation).join('\n'),
            largeur: _wObs, fill: fill),
      ]));
    }
    sb.write('</w:tbl>');
    return sb.toString();
  }

  /// Assemble les lignes d'une cellule : position (1ere) puis precisions,
  /// ces dernieres indentees.
  static String _imbriquer(List<String> lignes) {
    if (lignes.isEmpty) return '';
    final buffer = StringBuffer(lignes.first);
    for (final l in lignes.skip(1)) {
      buffer.write('\n    $l');
    }
    return buffer.toString();
  }

  static String _bord(String cote) =>
      '<w:$cote w:val="single" w:sz="4" w:space="0" w:color="808080"/>';

  static String _tr(List<String> cellules) => '<w:tr>${cellules.join()}</w:tr>';

  static String _tc(
    String texte, {
    required int largeur,
    bool bold = false,
    String align = 'left',
    String? fill,
  }) {
    final lignes = texte.split('\n');
    final paragraphes = StringBuffer();
    for (var i = 0; i < lignes.length; i++) {
      paragraphes.write(_p(
        lignes[i],
        bold: i == 0 && bold,
        taille: 16,
        align: align,
      ));
    }
    return '<w:tc><w:tcPr><w:tcW w:w="$largeur" w:type="dxa"/>'
        '${fill == null ? '' : '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/>'}'
        '<w:vAlign w:val="center"/></w:tcPr>'
        '$paragraphes</w:tc>';
  }

  static String _p(
    String texte, {
    bool bold = false,
    int taille = 20,
    String align = 'left',
  }) {
    final rpr = '<w:rPr>${bold ? '<w:b/>' : ''}'
        '<w:sz w:val="$taille"/><w:szCs w:val="$taille"/></w:rPr>';
    return '<w:p><w:pPr><w:jc w:val="$align"/>'
        '<w:spacing w:after="20"/>$rpr</w:pPr>'
        '<w:r>$rpr<w:t xml:space="preserve">${_esc(texte)}</w:t></w:r></w:p>';
  }

  static String _esc(String texte) => texte
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static const String _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="png" ContentType="image/png"/>'
      '<Override PartName="/word/document.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';

  static const String _rels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/></Relationships>';

  static const String _documentRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
      'Target="media/image1.png"/></Relationships>';
}
