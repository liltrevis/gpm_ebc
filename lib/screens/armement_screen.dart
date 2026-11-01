import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/arme.dart';
import '../providers/armement_provider.dart';
import '../providers/auth_provider.dart';
import 'mouvement_form_screen.dart';

/// Ecran du parc d'armement (armes, munitions, mouvements).
class ArmementScreen extends StatefulWidget {
  const ArmementScreen({super.key});

  @override
  State<ArmementScreen> createState() => _ArmementScreenState();
}

class _ArmementScreenState extends State<ArmementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArmementProvider>().charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ArmementProvider>();
    final auth = context.watch<AuthProvider>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        floatingActionButton: auth.peut('armement.move')
            ? FloatingActionButton.extended(
                heroTag: 'fab_armement',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MouvementFormScreen()),
                  );
                  if (mounted) context.read<ArmementProvider>().charger();
                },
                icon: const Icon(Icons.swap_vert),
                label: const Text('Mouvement'),
              )
            : null,
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Armes'),
                Tab(text: 'Munitions'),
                Tab(text: 'Mouvements'),
              ],
            ),
            Expanded(
              child: prov.loading && prov.armes.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _armes(prov),
                        _munitions(prov),
                        _mouvements(prov),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _armes(ArmementProvider prov) {
    if (prov.armes.isEmpty) return const Center(child: Text('Aucune arme.'));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: prov.armes.length,
      itemBuilder: (context, i) {
        final a = prov.armes[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.gavel),
            title: Text(a.numeroSerie),
            subtitle: Text('${a.typeLibelle ?? ''} - ${a.calibre ?? ''}'),
            trailing: _badge(a),
          ),
        );
      },
    );
  }

  Widget _munitions(ArmementProvider prov) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: prov.munitions.length,
      itemBuilder: (context, i) {
        final m = prov.munitions[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Icon(m.enAlerte ? Icons.warning_amber : Icons.inventory_2,
                color: m.enAlerte ? AppTheme.red : AppTheme.green),
            title: Text(m.designation),
            subtitle: Text('${m.typeCalibre} - seuil ${m.seuilAlerte}'),
            trailing: Text('${m.stockActuel} ${m.unite}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: m.enAlerte ? AppTheme.red : null)),
          ),
        );
      },
    );
  }

  Widget _mouvements(ArmementProvider prov) {
    if (prov.mouvements.isEmpty) {
      return const Center(child: Text('Aucun mouvement enregistre.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: prov.mouvements.length,
      itemBuilder: (context, i) {
        final m = prov.mouvements[i];
        final sortie = m.sens == 'SORTIE';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Icon(sortie ? Icons.logout : Icons.login,
                color: sortie ? AppTheme.amber : AppTheme.green),
            title: Text('${m.sens} - ${m.armeNumero ?? m.munitionDesignation ?? ''}'),
            subtitle: Text(
                '${formatDateHeureFr(m.dateHeure)}\n${m.beneficiaireNom ?? ''} ${m.motif ?? ''}'),
            isThreeLine: true,
            trailing: m.quantite > 1 ? Text('x${m.quantite}') : null,
          ),
        );
      },
    );
  }

  Widget _badge(Arme a) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: a.disponible
            ? AppTheme.green.withValues(alpha: 0.15)
            : AppTheme.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(a.etat, style: const TextStyle(fontSize: 11)),
    );
  }
}
