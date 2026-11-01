import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database.dart';

/// Erreur de sauvegarde/restauration (message destine a l'utilisateur).
class SauvegardeException implements Exception {
  SauvegardeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Export et import du fichier de base de donnees (echange entre appareils).
class SauvegardeService {
  /// Copie la base courante dans un fichier temporaire et renvoie ce fichier.
  static Future<File> preparerCopie() async {
    final source = await AppDatabase.instance.chemin;
    final dir = await getTemporaryDirectory();
    final dest = File(p.join(dir.path, 'gpm_ebc_${_horodatage(DateTime.now())}.db'));
    await File(source).copy(dest.path);
    return dest;
  }

  /// Valide [fichier] puis remplace la base courante par son contenu.
  static Future<void> importer(File fichier) async {
    final erreur = await _valider(fichier);
    if (erreur != null) throw SauvegardeException(erreur);
    await AppDatabase.instance.remplacerPar(fichier);
  }

  /// Renvoie `null` si le fichier est une sauvegarde valide, sinon le message
  /// d'erreur a afficher.
  static Future<String?> _valider(File fichier) async {
    if (!await fichier.exists()) return 'Fichier introuvable.';
    if (await fichier.length() < 100) return 'Fichier vide ou incomplet.';

    final raf = await fichier.open();
    final entete = await raf.read(16);
    await raf.close();
    if (String.fromCharCodes(entete) != 'SQLite format 3\u0000') {
      return 'Ce fichier n\'est pas une base de donnees GPM-2EBC.';
    }

    // On travaille sur une copie en cache pour ne pas modifier le fichier source.
    final dir = await getTemporaryDirectory();
    final copie = File(
        p.join(dir.path, 'verif_${DateTime.now().microsecondsSinceEpoch}.db'));
    Database? db;
    try {
      await fichier.copy(copie.path);
      db = await openDatabase(copie.path);
      final tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      final noms = tables.map((t) => t['name']).whereType<String>().toSet();
      if (!noms.contains('personnel') || !noms.contains('utilisateur')) {
        return 'Cette base ne provient pas de GPM-2EBC.';
      }
      final v = await db.rawQuery('PRAGMA user_version');
      final version = (v.first.values.first as int?) ?? 0;
      if (version > AppDatabase.version) {
        return 'Sauvegarde trop recente (version $version). '
            'Mettez a jour l\'application.';
      }
    } catch (_) {
      return 'Lecture de la sauvegarde impossible (fichier corrompu ?).';
    } finally {
      await db?.close();
      if (await copie.exists()) await copie.delete();
    }
    return null;
  }

  static String _horodatage(DateTime d) =>
      '${d.year}${_deux(d.month)}${_deux(d.day)}_'
      '${_deux(d.hour)}${_deux(d.minute)}';

  static String _deux(int n) => n.toString().padLeft(2, '0');
}
