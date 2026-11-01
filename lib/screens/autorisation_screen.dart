import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/autorisations.dart';
import '../core/theme.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/autorisation_provider.dart';
import '../providers/referentiel_provider.dart';

/// Ecran des autorisations de modification des chefs de peloton.
/// Le Commandant Escadron les accorde ; le Chef de Peloton les consulte.
class AutorisationScreen extends StatefulWidget {
  const AutorisationScreen({super.key});

  @override
  State<AutorisationScreen> createState() => _AutorisationScreenState();
}

class _AutorisationScreenState extends State<AutorisationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReferentielProvider>().charger();
      context.read<AutorisationProvider>().charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(auth.estChefPeloton
            ? 'Mes autorisations'
            : 'Autorisations des chefs'),
      ),
      body: auth.estChefPeloton
          ? _vueChef(context, auth.user)
          : _vueCommandant(context),
    );
  }

  Widget _note(String texte) => Card(
        color: AppTheme.amber.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(texte, style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
      );

  Future<void> _basculer(int sectionId, String code, bool valeur) async {
    await context.read<AutorisationProvider>().definir(
          sectionId: sectionId,
          code: code,
          accorde: valeur,
          acteur: context.read<AuthProvider>().user,
        );
  }

  /// Vue du Chef de Peloton : consultation de ses autorisations.
  Widget _vueChef(BuildContext context, AppUser? user) {
    final autor = context.watch<AutorisationProvider>();
    final section =
        context.watch<ReferentielProvider>().sectionParId(user?.sectionId);
    final sectionId = user?.sectionId;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _note('Vous ne pouvez modifier les donnees de votre peloton que si le '
            'Commandant Escadron vous y a autorise.'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(section?.libelle ?? 'Mon peloton'),
            subtitle: const Text('Peloton rattache a votre compte'),
          ),
        ),
        const SizedBox(height: 8),
        for (final a in kAutorisations)
          Builder(builder: (context) {
            final accordee = autor.estAccordee(sectionId, a.code);
            return Card(
              child: ListTile(
                leading: Icon(
                  accordee ? Icons.check_circle : Icons.cancel,
                  color: accordee ? AppTheme.green : Colors.grey,
                ),
                title: Text(a.libelle),
                subtitle: Text(a.description),
                trailing: Text(
                  accordee ? 'Autorisee' : 'Non autorisee',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accordee ? AppTheme.green : Colors.grey,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  /// Vue du Commandant Escadron : octroi des autorisations par peloton.
  Widget _vueCommandant(BuildContext context) {
    final autor = context.watch<AutorisationProvider>();
    final sections = context.watch<ReferentielProvider>().sections;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _note('Un chef de peloton ne peut modifier les donnees de son peloton '
            'que si vous l\'y autorisez. Les autorisations sont propres a '
            'chaque peloton.'),
        for (final s in sections)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading:
                    const CircleAvatar(child: Icon(Icons.groups, size: 20)),
                title: Text(s.libelle),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final a in kAutorisations)
                    SwitchListTile(
                      dense: true,
                      title: Text(a.libelle),
                      subtitle: Text(a.description,
                          style: const TextStyle(fontSize: 11)),
                      value: autor.estAccordee(s.id, a.code),
                      onChanged: (v) => _basculer(s.id, a.code, v),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
