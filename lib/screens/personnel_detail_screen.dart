import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/autorisations.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/personnel.dart';
import '../providers/auth_provider.dart';
import '../providers/autorisation_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/personnel_provider.dart';
import '../providers/referentiel_provider.dart';
import '../widgets/position_editeur.dart';
import 'personnel_form_screen.dart';

/// Fiche detaillee d'un militaire.
class PersonnelDetailScreen extends StatefulWidget {
  final int militaireId;
  const PersonnelDetailScreen({super.key, required this.militaireId});

  @override
  State<PersonnelDetailScreen> createState() => _PersonnelDetailScreenState();
}

class _PersonnelDetailScreenState extends State<PersonnelDetailScreen> {
  Personnel? _p;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    final p = await context.read<PersonnelProvider>().detail(widget.militaireId);
    if (mounted) {
      setState(() {
        _p = p;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final autorisations = context.watch<AutorisationProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_p?.nomPrenoms ?? 'Fiche'),
        actions: [
          if (_p != null && auth.peut('personnel.update'))
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PersonnelFormScreen(personnel: _p)),
                );
                _charger();
              },
            ),
          if (_p != null &&
              auth.peut('statut.update') &&
              autorisations.autorisePour(auth.user, AutorisationCode.statut))
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Changer le statut',
              onPressed: _changerStatut,
            ),
          if (_p != null && auth.peut('personnel.delete'))
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archiver',
              onPressed: _archiver,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _p == null
              ? const Center(child: Text('Militaire introuvable.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _entete(_p!),
                    _section('Identification', [
                      _ligne('Grade', _p!.gradeCode ?? _p!.gradeLibelle),
                      _ligne('Nom et prenoms', _p!.nomPrenoms),
                      _ligne('Matricule', _p!.matricule),
                      _ligne('Mecano', _p!.mecano),
                      _ligne('Categorie', _p!.categorieLibelle),
                      _ligne('Genre', _p!.genre),
                      _ligne('Date de naissance', formatDateFr(_p!.dateNaissance)),
                      _ligne('Lieu de naissance', _p!.lieuNaissance),
                    ]),
                    _section('Affectation', [
                      _ligne('Peloton', _p!.sectionLibelle),
                      _ligne('Fonction', _p!.fonctionLibelle),
                      PositionLigne(personnel: _p!, onChanged: _charger),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PositionServiceChip(militaireId: _p!.id),
                      ),
                      _ligne('Date debut service', formatDateFr(_p!.dateDebutService)),
                      _ligne('Unite de provenance', _p!.uniteProvenance),
                      _ligne('Date arrivee corps', formatDateFr(_p!.dateArriveeCorps)),
                    ]),
                    _section('Formation et diplomes', [
                      _ligne('Diplome militaire', _p!.diplomeMilitaire),
                      _ligne('Diplome civil', _p!.diplomeCivil),
                      _ligne('Niveau d\'etude', _p!.niveauEtude),
                      _ligne('Promotion', _p!.promotionClasse),
                    ]),
                    _section('Famille et contact', [
                      _ligne('Situation matrimoniale ID', '${_p!.situationMatrimonialeId ?? '-'}'),
                      _ligne('Conjoint', _p!.nomConjoint),
                      _ligne('Nombre d\'enfants', '${_p!.nombreEnfants ?? '-'}'),
                      _ligne('Telephone', _p!.telephone),
                      _ligne('Personne a appeler', _p!.personneAppeler),
                      _ligne('Habitation', _p!.lieuHabitation),
                    ]),
                    _section('Donnees administratives', [
                      _ligne('N CIM', _p!.numeroCim),
                      _ligne('CNI', _p!.cni),
                      _ligne('NNI', _p!.nni),
                      _ligne('Passeport', _p!.passeport),
                      _ligne('MUGFCI', _p!.mugfci),
                      _ligne('FPM', _p!.fpm),
                      _ligne('CMU', _p!.cmu),
                      _ligne('Livret matricule', _p!.livretMatricule),
                      _ligne('Dossier pension', _p!.dossierPension),
                      _ligne('Taille (m)', _p!.taille?.toString()),
                    ]),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _entete(Personnel p) {
    final ref = context.watch<ReferentielProvider>();
    final couleur = p.disponible ? AppTheme.green : AppTheme.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: couleur,
              child: Text((p.gradeCode ?? '?').substring(0, 1),
                  style: const TextStyle(color: Colors.white, fontSize: 20)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nomPrenoms, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('${p.gradeCode ?? p.gradeLibelle ?? ''} - ${ref.statutParId(p.statutId)?.libelle ?? p.statutLibelle ?? ''}'),
                  Text('Peloton : ${p.sectionLibelle ?? '-'}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String titre, List<Widget> enfants) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: Theme.of(context).textTheme.titleSmall),
            const Divider(),
            ...enfants,
          ],
        ),
      ),
    );
  }

  Widget _ligne(String libelle, String? valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(libelle)),
          Expanded(
            child: Text(
              (valeur == null || valeur.isEmpty) ? '-' : valeur,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changerStatut() async {
    final ref = context.read<ReferentielProvider>();
    final prov = context.read<PersonnelProvider>();
    final auth = context.read<AuthProvider>();
    final motif = TextEditingController();
    int? statutId = _p!.statutId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Changer le statut',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: statutId,
                    decoration: const InputDecoration(labelText: 'Nouveau statut'),
                    items: ref.statuts
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.libelle),
                            ))
                        .toList(),
                    onChanged: (v) => setSheet(() => statutId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: motif,
                    decoration: const InputDecoration(
                        labelText: 'Motif / reference (facultatif)'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: statutId == null
                        ? null
                        : () async {
                            await prov.changerStatut(
                              militaireId: _p!.id!,
                              statutId: statutId!,
                              motif: motif.text.trim().isEmpty ? null : motif.text.trim(),
                              acteur: auth.user,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            await _charger();
                            if (mounted) {
                              await context.read<DashboardProvider>().charger();
                            }
                          },
                    child: const Text('Enregistrer'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _archiver() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiver le militaire ?'),
        content: const Text('Le militaire sera retire des effectifs actifs.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    final prov = context.read<PersonnelProvider>();
    final auth = context.read<AuthProvider>();
    await prov.archiver(_p!.id!, acteur: auth.user);
    if (mounted) Navigator.of(context).pop();
  }
}
