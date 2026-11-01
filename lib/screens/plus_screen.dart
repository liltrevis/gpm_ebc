import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/autorisations.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/autorisation_provider.dart';
import 'admin_screen.dart';
import 'armement_screen.dart';
import 'autorisation_screen.dart';
import 'sauvegarde_screen.dart';

/// Menu "Plus" : rapports, administration, synchronisation, profil.
class PlusScreen extends StatelessWidget {
  const PlusScreen({super.key});

  String _resume(AppUser? user, AutorisationProvider autor) {
    final n = kAutorisations
        .where((a) => autor.estAccordee(user?.sectionId, a.code))
        .length;
    return '$n/${kAutorisations.length} autorisation(s) accordee(s)';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final autor = context.watch<AutorisationProvider>();
    final user = auth.user;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?.nomComplet ?? 'Utilisateur'),
            subtitle: Text(user?.roleLibelle ?? ''),
          ),
        ),
        Card(
          child: Column(
            children: [
              if (auth.peut('armement.read'))
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Armement'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ArmementScreen()),
                  ),
                ),
              if (auth.peut('admin.manage'))
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Administration'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(
                  auth.estChefPeloton
                      ? 'Mes autorisations'
                      : 'Autorisations des chefs',
                ),
                subtitle: auth.estChefPeloton
                    ? Text(_resume(user, autor))
                    : const Text('Droits de modification des chefs de peloton'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AutorisationScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Sauvegarde et échange'),
                subtitle: const Text(
                    'Exporter / importer la base entre appareils'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SauvegardeScreen()),
                ),
              ),
            ],
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Se deconnecter'),
            onTap: () => context.read<AuthProvider>().deconnexion(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'GPM-2EBC v1.0 - Application de gestion du personnel\nMode hors-ligne (SQLite)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
