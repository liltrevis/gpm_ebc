import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/autorisations.dart';
import '../models/service.dart';
import '../providers/auth_provider.dart';
import '../providers/autorisation_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/personnel_provider.dart';
import '../providers/service_provider.dart';
import 'service_form_screen.dart';
import 'service_poste_screen.dart';

/// Liste des services planifies / effectues.
class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceProvider>().charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ServiceProvider>();
    final auth = context.watch<AuthProvider>();
    final autorisations = context.watch<AutorisationProvider>();
    final peutCreer = auth.peut('service.create') &&
        autorisations.autorisePour(auth.user, AutorisationCode.service);
    return Scaffold(
      floatingActionButton: peutCreer
          ? FloatingActionButton.extended(
              heroTag: 'fab_service',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ServiceFormScreen()),
                );
                if (mounted) await _rafraichirTout();
              },
              icon: const Icon(Icons.add),
              label: const Text('Créer un service'),
            )
          : null,
      body: prov.loading && prov.liste.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : prov.liste.isEmpty
              ? const Center(child: Text('Aucun service enregistre.'))
              : RefreshIndicator(
                  onRefresh: () => context.read<ServiceProvider>().charger(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: prov.liste.length,
                    itemBuilder: (context, i) {
                      final s = prov.liste[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${s.affectations.length}')),
                          title: Text('${s.nom}${(s.posteLibelle ?? '').isEmpty ? '' : ' - ${s.posteLibelle}'}'),
                          subtitle: Text(
                            '${_dateFr(s.date)}  ${s.creneauDebut ?? ''}-${s.creneauFin ?? ''}  (${s.dureeHeures}h)\n'
                            '${s.affectations.take(3).map((a) => a.militaireNom).whereType<String>().join(', ')}'
                            '${s.affectations.length > 3 ? '...' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _badge(s),
                              if (peutCreer)
                                PopupMenuButton<String>(
                                  tooltip: 'Options',
                                  onSelected: (v) {
                                    if (v == 'modifier') _modifier(s);
                                    if (v == 'supprimer') _supprimer(s);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'modifier',
                                        child: ListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.edit_outlined),
                                          title: Text('Modifier'),
                                        )),
                                    PopupMenuItem(
                                        value: 'supprimer',
                                        child: ListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.delete_outline),
                                          title: Text('Supprimer'),
                                        )),
                                  ],
                                ),
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ServicePosteScreen(service: s),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  /// Recharge les services et les onglets lies (Effectifs, Tableau de bord,
  /// positions derivees "En service" / "De faction").
  Future<void> _rafraichirTout() async {
    await context.read<ServiceProvider>().charger();
    if (!mounted) return;
    await context.read<ServiceProvider>().chargerPositions();
    if (!mounted) return;
    await context.read<PersonnelProvider>().charger();
    if (!mounted) return;
    await context.read<DashboardProvider>().charger();
  }

  String _dateFr(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return ymd;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Widget _badge(ServiceModel s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: s.valide ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(s.statut, style: const TextStyle(fontSize: 11)),
    );
  }

  Future<void> _modifier(ServiceModel s) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ServiceFormScreen(service: s)),
    );
    if (ok == true && mounted) await _rafraichirTout();
  }

  Future<void> _supprimer(ServiceModel s) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le service'),
        content: const Text(
            'Supprimer définitivement ce service et tout le personnel qui y est affecté ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    await context
        .read<ServiceProvider>()
        .supprimerService(s.id!, acteur: context.read<AuthProvider>().user);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service supprimé.')),
      );
      await _rafraichirTout();
    }
  }
}
