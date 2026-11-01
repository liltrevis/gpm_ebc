import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/autorisation_provider.dart';
import '../providers/personnel_provider.dart';
import '../providers/referentiel_provider.dart';
import '../widgets/position_editeur.dart';
import 'modifier_groupe_screen.dart';
import 'personnel_detail_screen.dart';
import 'personnel_form_screen.dart';

/// Liste et recherche des militaires.
class PersonnelListScreen extends StatefulWidget {
  const PersonnelListScreen({super.key});

  @override
  State<PersonnelListScreen> createState() => _PersonnelListScreenState();
}

class _PersonnelListScreenState extends State<PersonnelListScreen> {
  final _recherche = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PersonnelProvider>().charger();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PersonnelProvider>();
    final ref = context.watch<ReferentielProvider>();
    final auth = context.watch<AuthProvider>();
    final autorisations = context.watch<AutorisationProvider>();

    return Scaffold(
      floatingActionButton: auth.peut('personnel.create')
          ? FloatingActionButton.extended(
              heroTag: 'fab_personnel',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PersonnelFormScreen()),
                );
                if (mounted) context.read<PersonnelProvider>().charger();
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Ajouter'),
            )
          : null,
      body: Column(
        children: [
          if (peutModifierPosition(auth, autorisations))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ModifierGroupeScreen(),
                      ),
                    );
                    if (mounted) context.read<PersonnelProvider>().charger();
                  },
                  icon: const Icon(Icons.groups_2_outlined),
                  label: const Text('Modifier un groupe'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _recherche,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher (nom, matricule, mecano, grade)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => context.read<PersonnelProvider>().rechercher(v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: prov.perimetreSectionId ?? prov.filtreSectionId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Peloton',
                          helperText: prov.perimetreSectionId != null
                              ? 'Limité à votre peloton'
                              : null,
                        ),
                        items: [
                          if (prov.perimetreSectionId == null)
                            const DropdownMenuItem(
                                value: null, child: Text('Toutes')),
                          ...ref.sections.map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.libelle),
                              )),
                        ],
                        onChanged: prov.perimetreSectionId != null
                            ? null
                            : (v) => context
                                .read<PersonnelProvider>()
                                .filtrerParSection(v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: prov.filtreStatutCode,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Statut'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tous')),
                          ...ref.statuts.map((s) => DropdownMenuItem(
                                value: s.code,
                                child: Text(s.libelle),
                              )),
                        ],
                        onChanged: (v) =>
                            context.read<PersonnelProvider>().filtrerParStatut(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _ouvrirTri,
                    icon: const Icon(Icons.sort),
                    label: Text(
                      prov.trisEffectif.isEmpty
                          ? 'Trier par'
                          : 'Tri : ${prov.trisEffectif.map(_libelleTri).join(' > ')}',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: prov.loading && prov.liste.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : prov.liste.isEmpty
                    ? const Center(child: Text('Aucun militaire trouve.'))
                    : RefreshIndicator(
                        onRefresh: () => context.read<PersonnelProvider>().charger(),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: prov.liste.length,
                          itemBuilder: (context, i) {
                            final p = prov.liste[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: p.disponible
                                      ? AppTheme.green
                                      : AppTheme.red,
                                  child: Text(
                                    (p.gradeCode ?? '?').substring(0, 1),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(p.nomPrenoms),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p.gradeCode ?? p.gradeLibelle ?? ''} - ${p.sectionLibelle ?? '-'}\n'
                                      'Mat: ${p.matricule ?? '-'}  Mec: ${p.mecano ?? '-'}',
                                    ),
                                    const SizedBox(height: 4),
                                    PositionChip(personnel: p),
                                    PositionServiceChip(militaireId: p.id),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: _badge(p.statutLibelle ?? '-'),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PersonnelDetailScreen(militaireId: p.id!),
                                    ),
                                  );
                                  if (mounted) context.read<PersonnelProvider>().charger();
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _ouvrirTri() async {
    final prov = context.read<PersonnelProvider>();
    final resultat = await showModalBottomSheet<List<TriEffectif>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TriPanel(initial: prov.trisEffectif),
    );
    if (resultat != null && mounted) {
      context.read<PersonnelProvider>().definirTris(resultat);
    }
  }

  Widget _badge(String texte) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.slate.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texte, style: const TextStyle(fontSize: 11)),
    );
  }
}

String _libelleTri(TriEffectif tri) {
  switch (tri) {
    case TriEffectif.peloton:
      return 'Peloton';
    case TriEffectif.categorie:
      return 'Catégories (OFF, S-OFF, MDR)';
    case TriEffectif.grade:
      return 'Grades';
    case TriEffectif.nom:
      return 'Noms';
  }
}

/// Panneau de choix du tri (1er + 2e niveau).
class _TriPanel extends StatefulWidget {
  final List<TriEffectif> initial;
  const _TriPanel({required this.initial});

  @override
  State<_TriPanel> createState() => _TriPanelState();
}

class _TriPanelState extends State<_TriPanel> {
  late List<TriEffectif?> _tris;

  @override
  void initState() {
    super.initState();
    _tris = List<TriEffectif?>.from(widget.initial.take(2));
    if (_tris.isEmpty) _tris = [null];
  }

  bool _utiliseAilleurs(TriEffectif tri, int index) {
    for (var j = 0; j < _tris.length; j++) {
      if (j != index && _tris[j] == tri) return true;
    }
    return false;
  }

  void _appliquer() {
    Navigator.pop(
      context,
      _tris.whereType<TriEffectif>().toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Trier par',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () => setState(() => _tris = [null]),
                  child: const Text('Réinitialiser'),
                ),
              ],
            ),
            for (var i = 0; i < _tris.length; i++) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TriEffectif>(
                      value: _tris[i],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: i == 0 ? '1er tri' : '2e tri',
                      ),
                      items: [
                        for (final t in TriEffectif.values)
                          if (!_utiliseAilleurs(t, i))
                            DropdownMenuItem(
                              value: t,
                              child: Text(_libelleTri(t)),
                            ),
                      ],
                      onChanged: (v) => setState(() => _tris[i] = v),
                    ),
                  ),
                  if (i > 0)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _tris.removeAt(i)),
                    ),
                ],
              ),
            ],
            if (_tris.length < 2)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _tris.add(null)),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un 2e tri'),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _appliquer,
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }
}
