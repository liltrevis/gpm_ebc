import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'app_reload.dart';
import 'data/autorisation_repository.dart';
import 'data/database.dart';
import 'data/database_factory.dart';
import 'data/personnel_repository.dart';
import 'data/rapport_repository.dart';
import 'data/referentiel_repository.dart';
import 'data/service_repository.dart';
import 'data/utilisateur_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/autorisation_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/personnel_provider.dart';
import 'providers/referentiel_provider.dart';
import 'providers/service_provider.dart';
import 'providers/sync_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDatabaseFactory();
  runApp(const GpmRoot());
}

/// Racine de l'application : ouvre la base puis (re)construit tous les
/// fournisseurs. Se reconstruit entierement lorsqu'un import de sauvegarde
/// demande un rechargement ([rechargerApplication]).
class GpmRoot extends StatefulWidget {
  const GpmRoot({super.key});

  @override
  State<GpmRoot> createState() => _GpmRootState();
}

class _GpmRootState extends State<GpmRoot> {
  late Future<Database> _base;

  @override
  void initState() {
    super.initState();
    _base = AppDatabase.instance.database;
    signalRechargement.addListener(_recharger);
  }

  @override
  void dispose() {
    signalRechargement.removeListener(_recharger);
    super.dispose();
  }

  void _recharger() {
    setState(() => _base = AppDatabase.instance.database);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Database>(
      future: _base,
      builder: (context, snap) {
        if (snap.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur base de données :\n${snap.error}'),
                ),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        final db = snap.data!;
        return MultiProvider(
          providers: [
            Provider<Database>.value(value: db),
            ChangeNotifierProvider(
              create: (_) => AuthProvider(UtilisateurRepository(db)),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  AutorisationProvider(AutorisationRepository(db))..charger(),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  ReferentielProvider(ReferentielRepository(db))..charger(),
            ),
            ChangeNotifierProvider(
              create: (_) => PersonnelProvider(PersonnelRepository(db)),
            ),
            ChangeNotifierProvider(
              create: (_) => ServiceProvider(ServiceRepository(db)),
            ),
            ChangeNotifierProvider(
              create: (_) => DashboardProvider(RapportRepository(db)),
            ),
            ChangeNotifierProvider(create: (_) => SyncProvider(db)),
          ],
          child: const GpmApp(),
        );
      },
    );
  }
}
