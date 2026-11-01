import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Incruste une image (PNG) dans la premiere feuille d'un classeur .xlsx.
///
/// Le paquet `excel` genere deja les parties OOXML necessaires
/// (partie de dessin vide, relation de feuille et content-type). On complete :
/// - remplit `xl/drawings/drawing1.xml` avec l'image ;
/// - cree `xl/drawings/_rels/drawing1.xml.rels` ;
/// - ajoute `xl/media/image1.png` ;
/// - declare le type d'image dans `[Content_Types].xml` ;
/// - reference le dessin dans `xl/worksheets/sheet1.xml`.
class OoxmlLogo {
  static const String _partContentTypes = '[Content_Types].xml';
  static const String _partDrawing = 'xl/drawings/drawing1.xml';
  static const String _partDrawingRels = 'xl/drawings/_rels/drawing1.xml.rels';
  static const String _partMedia = 'xl/media/image1.png';
  static const String _partSheet = 'xl/worksheets/sheet1.xml';

  /// Retourne le classeur `xlsx` avec le logo incruste dans la 1re feuille.
  /// Renvoie `xlsx` inchange en cas d'echec.
  static Uint8List injecter(Uint8List xlsx, Uint8List imagePng) {
    try {
      final archive = ZipDecoder().decodeBytes(xlsx, verify: false);
      final sortie = Archive();
      for (final f in archive.files) {
        if (!f.isFile) continue;
        final contenu = f.content;
        final data = contenu is List<int> ? contenu : const <int>[];
        if (f.name == _partContentTypes) {
          sortie.addFile(_fichier(f.name, utf8.encode(_avecDefault(data))));
        } else if (f.name == _partDrawing) {
          sortie.addFile(_fichier(f.name, utf8.encode(_drawingXml)));
        } else if (f.name == _partSheet) {
          sortie.addFile(_fichier(f.name, utf8.encode(_avecDrawing(data))));
        } else {
          sortie.addFile(_fichier(f.name, data));
        }
      }
      sortie.addFile(_fichier(_partMedia, imagePng));
      sortie.addFile(_fichier(_partDrawingRels, utf8.encode(_drawingRels)));
      return Uint8List.fromList(ZipEncoder().encode(sortie)!);
    } catch (_) {
      return xlsx;
    }
  }

  static ArchiveFile _fichier(String nom, List<int> data) =>
      ArchiveFile(nom, data.length, data);

  static String _avecDefault(List<int> data) {
    final texte = utf8.decode(data);
    if (texte.contains('Extension="png"')) return texte;
    final i = texte.indexOf('<Types');
    if (i < 0) return texte;
    final j = texte.indexOf('>', i);
    if (j < 0) return texte;
    const defaut = '<Default ContentType="image/png" Extension="png"/>';
    return texte.substring(0, j + 1) + defaut + texte.substring(j + 1);
  }

  static String _avecDrawing(List<int> data) {
    final texte = utf8.decode(data);
    if (texte.contains('<drawing ')) return texte;
    return texte.replaceFirst(
        '</worksheet>', '<drawing r:id="rId1"/></worksheet>');
  }

  static const String _drawingXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<xdr:wsDr '
      'xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<xdr:oneCellAnchor>'
      '<xdr:from><xdr:col>4</xdr:col><xdr:colOff>0</xdr:colOff>'
      '<xdr:row>0</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>'
      '<xdr:ext cx="900000" cy="900000"/>'
      '<xdr:pic><xdr:nvPicPr>'
      '<xdr:cNvPr id="1" name="Logo escadron"/><xdr:cNvPicPr/>'
      '</xdr:nvPicPr>'
      '<xdr:blipFill><a:blip r:embed="rId1"/>'
      '<a:stretch><a:fillRect/></a:stretch></xdr:blipFill>'
      '<xdr:spPr><a:xfrm><a:off x="0" y="0"/>'
      '<a:ext cx="900000" cy="900000"/></a:xfrm>'
      '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr>'
      '</xdr:pic><xdr:clientData/></xdr:oneCellAnchor></xdr:wsDr>';

  static const String _drawingRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
      'Target="../media/image1.png"/></Relationships>';
}
