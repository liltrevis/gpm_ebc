import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initialise la fabrique SQLite selon la plateforme.
///
/// - Mobile (Android / iOS) et macOS : `sqflite` natif, aucune action requise.
/// - Desktop (Windows / Linux) : SQLite via FFI (sqlite3 v3 fournit la
///   librairie native automatiquement).
void initDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
