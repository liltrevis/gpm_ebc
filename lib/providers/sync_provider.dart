import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/journal.dart';

/// Etat de la file de synchronisation differee (offline-first).
class SyncProvider extends ChangeNotifier {
  final Database db;
  SyncProvider(this.db);

  int enAttente = 0;
  bool enCours = false;
  DateTime? derniereSync;

  Future<void> rafraichir() async {
    enAttente = await Journal.enAttente(db);
    notifyListeners();
  }

  /// Simule l'envoi des ecritures locales vers le serveur.
  Future<void> synchroniser() async {
    enCours = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(seconds: 1));
    await db.update('sync_outbox', {'synchronise': 1}, where: 'synchronise = 0');
    await rafraichir();
    enCours = false;
    derniereSync = DateTime.now();
    notifyListeners();
  }
}
