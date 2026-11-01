import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/champs_personnel.dart';
import '../core/format.dart';
import '../core/positions.dart';
import '../models/personnel.dart';
import '../models/referentiel.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/personnel_provider.dart';
import '../providers/referentiel_provider.dart';

/// Sentinelle de l'option "AJOUTER" du menu de precision.
const String _sentinelAjouter = '__AJOUTER__';

/// Modification d'une information (au choix parmi celles de la base de
/// donnees) pour un groupe de militaires selectionnes.
class ModifierGroupeScreen extends StatefulWidget {
  const ModifierGroupeScreen({super.key});

  @override
  State<ModifierGroupeScreen> createState() => _ModifierGroupeScreenState();
}

class _ModifierGroupeScreenState extends State<ModifierGroupeScreen> {
  final _recherche = TextEditingController();
  final _valeurTexte = TextEditingController();
  final _valeurAutre = TextEditingController();

  /// Sentinelle de l'option "Autre a preciser" des listes.
  static const int _autreId = -1;

  List<Personnel> _membres = [];
  final Set<int> _selection = {};
  bool _loading = true;
  bool _enCours = false;

  ChampPersonnel? _champ;
  int? _valeurRef;
  bool _estAutre = false;
  String? _valeurPosition;
  String? _valeurPrecision;
  String? _valeurDate;
  List<String> _precisions = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _recherche.dispose();
    _valeurTexte.dispose();
    _valeurAutre.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final tous = await context.read<PersonnelProvider>().parFiltre();
    if (!mounted) return;
    setState(() {
      _membres = tous;
      _loading = false;
    });
  }

  List<Personnel> get _visibles {
    final q = _recherche.text.trim().toLowerCase();
    if (q.isEmpty) return _membres;
    return _membres.where((p) {
      final texte = '${p.nomPrenoms} ${p.matricule ?? ''} '
              '${p.mecano ?? ''} ${p.gradeCode ?? ''} ${p.gradeLibelle ?? ''}'
          .toLowerCase();
      return texte.contains(q);
    }).toList();
  }

  void _toutSelectionner() => setState(() =>
      _selection.addAll(_visibles.map((p) => p.id).whereType<int>()));

  void _toutDecocher() => setState(() => _selection.clear());

  void _changerChamp(ChampPersonnel? champ) {
    setState(() {
      _champ = champ;
      _valeurTexte.clear();
      _valeurAutre.clear();
      _estAutre = false;
      _valeurRef = null;
      _valeurPosition = null;
      _valeurPrecision = null;
      _valeurDate = null;
      _precisions = [];
    });
    if (champ?.type == TypeChamp.position) {
      _valeurPosition = kPositions.isNotEmpty ? kPositions.first : null;
      _chargerPrecisions();
    }
  }

  List<RefItem> _options(ReferentielProvider ref) {
    switch (_champ?.tableRef) {
      case 'grades':
        return ref.grades;
      case 'categories':
        return ref.categories;
      case 'escadrons':
        return ref.escadrons;
      case 'sections':
        return ref.sections;
      case 'fonctions':
        return ref.fonctions;
      case 'groupesSanguins':
        return ref.groupesSanguins;
      case 'situationsMatrimoniales':
        return ref.situationsMatrimoniales;
      case 'domaines':
        return ref.domaines;
    }
    return const [];
  }

  Future<void> _chargerPrecisions() async {
    final pos = _valeurPosition;
    final base = pos == null ? <String>[] : precisionsPourPosition(pos);
    List<String> depuisDb = <String>[];
    if (pos != null) {
      try {
        depuisDb =
            await context.read<ReferentielProvider>().precisionsPosition(pos);
      } catch (_) {}
    }
    if (!mounted) return;
    final liste = <String>[...base];
    for (final e in depuisDb) {
      if (!liste.contains(e)) liste.add(e);
    }
    setState(() => _precisions = liste);
  }

  Future<void> _choisirDate() async {
    final initial = _valeurDate == null
        ? DateTime.now()
        : (DateTime.tryParse(_valeurDate!) ?? DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => _valeurDate =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}');
    }
  }

  Object? _valeur() {
    final champ = _champ!;
    switch (champ.type) {
      case TypeChamp.texte:
        return _valeurTexte.text.trim();
      case TypeChamp.entier:
        final t = _valeurTexte.text.trim();
        return t.isEmpty ? null : int.tryParse(t);
      case TypeChamp.nombre:
        final t = _valeurTexte.text.trim().replaceAll(',', '.');
        return t.isEmpty ? null : double.tryParse(t);
      case TypeChamp.date:
        return _valeurDate;
      case TypeChamp.referentiel:
      case TypeChamp.section:
      case TypeChamp.fonction:
        return _valeurRef;
      case TypeChamp.position:
        return _valeurPosition;
    }
  }

  Future<void> _appliquer() async {
    if (_champ == null) {
      _snack('Choisissez l\'information a modifier.');
      return;
    }
    if (_selection.isEmpty) {
      _snack('Selectionnez au moins une personne.');
      return;
    }
    final erreur = _erreur();
    if (erreur != null) {
      _snack(erreur);
      return;
    }
    final champ = _champ!;
    if (_estAutre &&
        (champ.type == TypeChamp.referentiel ||
            champ.type == TypeChamp.section ||
            champ.type == TypeChamp.fonction)) {
      setState(() => _enCours = true);
      try {
        final id = await context
            .read<ReferentielProvider>()
            .ajouterReferentiel(champ.tableRef!, _valeurAutre.text.trim());
        if (id <= 0) {
          _snack('Impossible d\'ajouter la valeur.');
          return;
        }
        setState(() => _valeurRef = id);
      } catch (e) {
        if (mounted) _snack('Ajout impossible: $e');
        return;
      } finally {
        if (mounted) setState(() => _enCours = false);
      }
    }
    final valeur = _valeur();
    final valeurAffichee = _valeurAffichee();

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la modification'),
        content: Text(
          'Modifier « ${champ.libelle} » pour ${_selection.length} personne(s) ?\n\n'
          'Nouvelle valeur : $valeurAffichee',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Appliquer')),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _enCours = true);
    try {
      await context.read<PersonnelProvider>().mettreAJourChampGroupe(
            militaireIds: _selection.toList(),
            champ: champ,
            valeur: valeur,
            positionPrecision:
                champ.type == TypeChamp.position ? _valeurPrecision : null,
            acteur: context.read<AuthProvider>().user,
          );
      if (!mounted) return;
      _snack('${_selection.length} fiche(s) mise(s) a jour.');
      setState(() => _selection.clear());
      await _charger();
      if (!mounted) return;
      await context.read<DashboardProvider>().charger();
    } catch (e) {
      if (mounted) _snack('Modification impossible: $e');
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  String _valeurAffichee() {
    final champ = _champ!;
    switch (champ.type) {
      case TypeChamp.position:
        return libellePosition(_valeurPosition, _valeurPrecision);
      case TypeChamp.referentiel:
      case TypeChamp.section:
      case TypeChamp.fonction:
        if (_estAutre) return _valeurAutre.text.trim();
        for (final o in _options(context.read<ReferentielProvider>())) {
          if (o.id == _valeurRef) return o.libelle;
        }
        return '-';
      case TypeChamp.date:
        return _valeurDate == null ? '-' : afficherDateFr(_valeurDate);
      case TypeChamp.texte:
      case TypeChamp.entier:
      case TypeChamp.nombre:
        final t = _valeurTexte.text.trim();
        return t.isEmpty ? '(vide)' : t;
    }
  }

  String? _erreur() {
    final champ = _champ!;
    if (champ.type == TypeChamp.entier &&
        _valeurTexte.text.trim().isNotEmpty &&
        int.tryParse(_valeurTexte.text.trim()) == null) {
      return 'Valeur numerique attendue.';
    }
    if (champ.type == TypeChamp.nombre &&
        _valeurTexte.text.trim().isNotEmpty &&
        double.tryParse(_valeurTexte.text.trim().replaceAll(',', '.')) ==
            null) {
      return 'Valeur numerique attendue.';
    }
    if ((champ.type == TypeChamp.date) && _valeurDate == null) {
      return 'Choisissez une date.';
    }
    if (champ.type == TypeChamp.referentiel ||
        champ.type == TypeChamp.section ||
        champ.type == TypeChamp.fonction) {
      if (_estAutre && _valeurAutre.text.trim().isEmpty) {
        return 'Saisissez la nouvelle valeur.';
      }
      if (!_estAutre && _valeurRef == null) {
        return 'Choisissez une valeur.';
      }
    }
    if (champ.type == TypeChamp.position && _valeurPosition == null) {
      return 'Choisissez une position.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ref = context.watch<ReferentielProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier un groupe'),
        // L'action reste visible en haut pendant le defilement de la liste.
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FilledButton.icon(
                onPressed: (_enCours || _champ == null) ? null : _appliquer,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: _enCours
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_alt, size: 18),
                label: Text('Appliquer (${_selection.length})'),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<ChampPersonnel>(
                  initialValue: _champ,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Information a modifier *',
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  items: [
                    for (final c in kChampsPersonnel)
                      DropdownMenuItem(value: c, child: Text(c.libelle)),
                  ],
                  onChanged: _enCours ? null : _changerChamp,
                ),
                const SizedBox(height: 12),
                if (_champ != null) _champValeur(ref),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Personnes concernees',
                        style: Theme.of(context).textTheme.titleSmall),
                    Text('${_selection.length} / ${_membres.length}'),
                  ],
                ),
                TextField(
                  controller: _recherche,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher (nom, matricule, mecano, grade)',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _visibles.isEmpty ? null : _toutSelectionner,
                      icon: const Icon(Icons.check_box_outlined, size: 18),
                      label: const Text('Tout sélectionner'),
                    ),
                    TextButton.icon(
                      onPressed: _selection.isEmpty ? null : _toutDecocher,
                      icon: const Icon(Icons.check_box_outline_blank, size: 18),
                      label: const Text('Tout décocher'),
                    ),
                  ],
                ),
                if (_visibles.isEmpty)
                  const Card(child: ListTile(title: Text('Aucun personnel.')))
                else
                  ..._visibles.map((p) {
                    return CheckboxListTile(
                      value: _inclut(p),
                      onChanged: _enCours
                          ? null
                          : (v) => setState(() {
                                if (v == true) {
                                  _selection.add(p.id!);
                                } else {
                                  _selection.remove(p.id);
                                }
                              }),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: Text(p.nomPrenoms),
                      subtitle: Text(
                        '${p.gradeCode ?? p.gradeLibelle ?? ''} '
                        '${p.matricule ?? ''} - ${p.sectionLibelle ?? '-'}',
                      ),
                    );
                  }),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  bool _inclut(Personnel p) => p.id != null && _selection.contains(p.id);

  Widget _champValeur(ReferentielProvider ref) {
    final champ = _champ!;
    switch (champ.type) {
      case TypeChamp.texte:
      case TypeChamp.entier:
      case TypeChamp.nombre:
        return TextField(
          controller: _valeurTexte,
          keyboardType: champ.type == TypeChamp.texte
              ? TextInputType.text
              : const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Nouvelle valeur',
            prefixIcon: const Icon(Icons.edit),
            suffixText: champ.type == TypeChamp.entier ? 'entier' : null,
          ),
        );
      case TypeChamp.date:
        return InkWell(
          onTap: _enCours ? null : _choisirDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Nouvelle date',
              prefixIcon: Icon(Icons.event),
            ),
            child: Text(_valeurDate == null
                ? 'Choisir une date'
                : afficherDateFr(_valeurDate)),
          ),
        );
      case TypeChamp.referentiel:
      case TypeChamp.section:
      case TypeChamp.fonction:
        final options = _options(ref);
        return Column(
          children: [
            DropdownButtonFormField<int>(
              initialValue: _valeurRef,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Nouvelle valeur',
                prefixIcon: Icon(Icons.list),
              ),
              items: [
                for (final o in options)
                  DropdownMenuItem(value: o.id, child: Text(o.libelle)),
                const DropdownMenuItem(
                  value: _autreId,
                  child: Text('Autre à préciser...',
                      style: TextStyle(fontStyle: FontStyle.italic)),
                ),
              ],
              onChanged: _enCours
                  ? null
                  : (v) => setState(() {
                        _valeurRef = v;
                        _estAutre = v == _autreId;
                      }),
            ),
            if (_estAutre) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _valeurAutre,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nouvelle valeur à enregistrer',
                  prefixIcon: Icon(Icons.create),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        );
      case TypeChamp.position:
        return Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _valeurPosition,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Nouvelle position',
                prefixIcon: Icon(Icons.place),
              ),
              items: [
                for (final p in kPositions)
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: _enCours
                  ? null
                  : (v) {
                      setState(() {
                        _valeurPosition = v;
                        _valeurPrecision = null;
                      });
                      _chargerPrecisions();
                    },
            ),
            if (_precisions.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _valeurPrecision,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Precision',
                  prefixIcon: Icon(Icons.tune),
                ),
                items: [
                  ..._precisions.map(
                      (p) => DropdownMenuItem(value: p, child: Text(p))),
                  const DropdownMenuItem(
                    value: _sentinelAjouter,
                    child: Text('+ AJOUTER',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
                onChanged: _enCours
                    ? null
                    : (v) {
                        if (v == _sentinelAjouter) {
                          _ajouterPrecision();
                        } else {
                          setState(() => _valeurPrecision = v);
                        }
                      },
              ),
            ],
          ],
        );
    }
  }

  Future<void> _ajouterPrecision() async {
    final ctrl = TextEditingController();
    final texte = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle precision'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Precision'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('Ajouter')),
        ],
      ),
    );
    final valeur = (texte ?? '').trim().toUpperCase();
    if (valeur.isEmpty || _valeurPosition == null) return;
    try {
      await context.read<ReferentielProvider>().ajouterPrecisionPosition(
            position: _valeurPosition!,
            libelle: valeur,
          );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      if (!_precisions.contains(valeur)) _precisions.add(valeur);
      _valeurPrecision = valeur;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
