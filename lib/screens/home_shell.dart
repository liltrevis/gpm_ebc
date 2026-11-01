import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/autorisation_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/personnel_provider.dart';
import '../providers/service_provider.dart';
import '../widgets/escadron_logo.dart';
import 'dashboard_screen.dart';
import 'etats_screen.dart';
import 'plus_screen.dart';
import 'personnel_list_screen.dart';
import 'service_list_screen.dart';

/// Coquille principale avec navigation par onglets.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _etatsKey = 0;

  @override
  void initState() {
    super.initState();
    // Restreint l'acces au peloton du Chef de Peloton connecte.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final perimetre = auth.perimetreSectionId;
      context.read<AutorisationProvider>().charger();
      context.read<PersonnelProvider>().definirPerimetre(perimetre);
      context.read<DashboardProvider>().definirPerimetre(perimetre);
      context.read<ServiceProvider>().definirPerimetre(
            sectionId: perimetre,
            createurId: auth.user?.id,
          );
    });
  }

  static const _titres = [
    'Tableau de bord',
    'Effectifs',
    'Services',
    'Etats',
    'Plus',
  ];

  /// Ouvre l'onglet Effectifs avec le filtre demande (depuis le tableau de bord).
  void _ouvrirEffectif({
    int? sectionId,
    List<String>? statutCodes,
    bool? disponible,
  }) {
    context.read<PersonnelProvider>().filtrerComplet(
          sectionId: sectionId,
          statutCodes: statutCodes,
          disponible: disponible,
        );
    setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        onOuvrirEffectif: _ouvrirEffectif,
        onOuvrirServices: () => setState(() => _index = 2),
      ),
      const PersonnelListScreen(),
      const ServiceListScreen(),
      EtatsScreen(key: ValueKey('etats$_etatsKey')),
      const PlusScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const EscadronLogo(size: 28),
            const SizedBox(width: 10),
            Text(_titres[_index]),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
            if (i == 3) _etatsKey++;
          });
          if (i == 0) {
            context.read<DashboardProvider>().charger();
            context.read<ServiceProvider>().chargerPositions();
          }
          if (i == 1) {
            context.read<PersonnelProvider>().charger();
            context.read<ServiceProvider>().chargerPositions();
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Bord'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Effectifs'),
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: 'Services'),
          NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'Etats'),
          NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'Plus'),
        ],
      ),
    );
  }
}
