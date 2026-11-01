import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/rbac.dart';
import '../data/utilisateur_repository.dart';
import '../models/app_user.dart';
import '../providers/referentiel_provider.dart';

/// Administration des comptes utilisateurs.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final UtilisateurRepository _repo;
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = UtilisateurRepository(context.read<Database>());
    _charger();
  }

  Future<void> _charger() async {
    final u = await _repo.lister();
    if (mounted) {
      setState(() {
        _users = u;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final referentiel = context.watch<ReferentielProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Administration - Comptes')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_admin',
        onPressed: _ajouter,
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: _users
                  .map((u) => Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(u.nomComplet),
                          subtitle: Text([
                            u.username,
                            u.roleLibelle,
                            if (u.estChefPeloton && u.sectionId != null)
                              referentiel.sectionParId(u.sectionId)?.libelle ?? '',
                          ].where((e) => e.isNotEmpty).join(' - ')),
                          onTap: () => _modifier(u),
                          trailing: Switch(
                            value: u.actif,
                            onChanged: (v) async {
                              await _repo.basculerActif(u.id!, v);
                              _charger();
                            },
                          ),
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  Future<void> _modifier(AppUser u) async {
    final sections = context.read<ReferentielProvider>().sections;
    String roleCode = kRoleLibelles.containsKey(u.roleCode)
        ? u.roleCode
        : RoleCode.chefPeloton;
    int? sectionId = u.sectionId ??
        (sections.isEmpty ? null : sections.first.id);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(u.nomComplet),
          content: StatefulBuilder(
            builder: (ctx, setD) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: roleCode,
                      decoration:
                          const InputDecoration(labelText: 'Type d\'utilisateur'),
                      items: kRoleLibelles.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (v) => setD(() => roleCode = v ?? roleCode),
                    ),
                    if (roleCode == RoleCode.chefPeloton)
                      DropdownButtonFormField<int>(
                        value: sectionId,
                        decoration: const InputDecoration(labelText: 'Peloton'),
                        items: sections
                            .map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.libelle),
                                ))
                            .toList(),
                        onChanged: (v) => setD(() => sectionId = v ?? sectionId),
                      ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                await _repo.modifierRoleEtSection(
                  u.id!,
                  roleCode: roleCode,
                  sectionId:
                      roleCode == RoleCode.chefPeloton ? sectionId : null,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                _charger();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _ajouter() async {
    final username = TextEditingController();
    final nom = TextEditingController();
    final motDePasse = TextEditingController();
    final sections = context.read<ReferentielProvider>().sections;
    String roleCode = RoleCode.chefPeloton;
    int? sectionId = sections.isEmpty ? null : sections.first.id;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nouveau compte'),
          content: StatefulBuilder(
            builder: (ctx, setD) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: username,
                      decoration: const InputDecoration(labelText: 'Identifiant'),
                    ),
                    TextField(
                      controller: nom,
                      decoration: const InputDecoration(labelText: 'Nom complet'),
                    ),
                    TextField(
                      controller: motDePasse,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Mot de passe'),
                    ),
                    DropdownButtonFormField<String>(
                      value: roleCode,
                      decoration: const InputDecoration(labelText: 'Type d\'utilisateur'),
                      items: kRoleLibelles.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (v) => setD(() => roleCode = v ?? roleCode),
                    ),
                    if (roleCode == RoleCode.chefPeloton)
                      DropdownButtonFormField<int>(
                        value: sectionId,
                        decoration: const InputDecoration(labelText: 'Peloton'),
                        items: sections
                            .map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.libelle),
                                ))
                            .toList(),
                        onChanged: (v) => setD(() => sectionId = v ?? sectionId),
                      ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (username.text.trim().isEmpty ||
                    nom.text.trim().isEmpty ||
                    motDePasse.text.isEmpty) {
                  return;
                }
                await _repo.creer(
                  username: username.text.trim(),
                  nomComplet: nom.text.trim(),
                  motDePasse: motDePasse.text,
                  roleCode: roleCode,
                  sectionId: roleCode == RoleCode.chefPeloton ? sectionId : null,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                _charger();
              },
              child: const Text('Creer'),
            ),
          ],
        );
      },
    );
  }
}
