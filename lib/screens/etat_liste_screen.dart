import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/colonnes_etat.dart';
import '../core/etats.dart';
import '../core/format.dart';
import '../core/positions.dart';
import '../models/personnel.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/personnel_provider.dart';
import '../providers/referentiel_provider.dart';
import '../providers/service_provider.dart';
import '../services/excel_service.dart';
import '../services/pdf_service.dart';
import '../widgets/colonnes_etat_dialog.dart';

/// Sentinelle de l'option "AJOUTER" du menu de precision.
const String _sentinelAjouter = '__AJOUTER__';

/// Compose un etat selon [mode] :
///  - [ModeEtat.liste] : liste nommee, selection libre du personnel, avec
///    proposition automatique possible (nombre total + categories de grade) ;
///  - [ModeEtat.position] : changement de position, configuration courante.
/// Une duree peut etre precisee, sinon elle est "indeterminee".
class EtatListeScreen extends StatefulWidget {
  final ModeEtat mode;
  const EtatListeScreen({super.key, this.mode = ModeEtat.position});

  @override
  State<EtatListeScreen> createState() => _EtatListeScreenState();
}

class _EtatListeScreenState extends State<EtatListeScreen> {
  final _nom = TextEditingController();
  final _duree = TextEditingController();
  List<Personnel> _membres = [];
  final Set<int> _exclus = {};
  bool _loading = true;

  String? _position;
  String? _precision;
  List<String> _precisions = [];

  Set<int> _idsDeFaction = {};
  bool _propositionActive = false;
  FiltreProposition _filtreActif = FiltreProposition.disponiblesAvecFaction;
  Map<String, int> _composition = {};

  bool get _estListe => widget.mode == ModeEtat.liste;

  @override
  void initState() {
    super.initState();
    if (!_estListe) {
      _position = kPositions.isNotEmpty ? kPositions.first : null;
      _nom.text = _position ?? '';
    }
    _charger();
    if (!_estListe) _chargerPrecisions();
    _chargerFactions();
  }

  Future<void> _charger() async {
    final tous = await context.read<PersonnelProvider>().parFiltre();
    if (!mounted) return;
    setState(() {
      _membres = tous;
      if (_estListe) {
        _exclus
          ..clear()
          ..addAll(List<int>.generate(tous.length, (i) => i));
      } else {
        _appliquerPosition(_position);
      }
      _loading = false;
    });
  }

  Future<void> _chargerFactions() async {
    try {
      final prov = context.read<ServiceProvider>();
      await prov.chargerPositions();
      if (!mounted) return;
      setState(() {
        _idsDeFaction = {
          for (final e in prov.positionsService.entries)
            if (e.value == 'De faction') e.key,
        };
      });
    } catch (_) {}
  }

  Future<void> _chargerPrecisions() async {
    final pos = _position;
    final base = pos == null ? <String>[] : precisionsPourPosition(pos);
    List<String> depuisDb = <String>[];
    if (pos != null) {
      try {
        depuisDb = await context.read<ReferentielProvider>().precisionsPosition(pos);
      } catch (_) {}
    }
    if (!mounted) return;
    final liste = <String>[...base];
    for (final e in depuisDb) {
      if (!liste.contains(e)) liste.add(e);
    }
    setState(() => _precisions = liste);
  }

  /// Recalcule les personnes exclues en fonction de la position choisie.
  void _appliquerPosition(String? pos) {
    final codes = pos == null ? <String>[] : [statutCodeDepuisPosition(pos)];
    _exclus.clear();
    for (var i = 0; i < _membres.length; i++) {
      final p = _membres[i];
      final dansRubrique = codes.isEmpty ||
          (p.statutCode != null && codes.contains(p.statutCode));
      if (!dansRubrique) _exclus.add(i);
    }
  }

  void _toutSelectionner() => setState(() => _exclus.clear());

  void _toutDecocher() => setState(() {
        _exclus
          ..clear()
          ..addAll(List<int>.generate(_membres.length, (i) => i));
      });

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
    if (valeur.isEmpty || _position == null) return;
    try {
      await context.read<ReferentielProvider>().ajouterPrecisionPosition(
            position: _position!,
            libelle: valeur,
          );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      if (!_precisions.contains(valeur)) _precisions.add(valeur);
      _precision = valeur;
    });
  }

  @override
  void dispose() {
    _nom.dispose();
    _duree.dispose();
    super.dispose();
  }

  int _rang(int index) {
    var n = 0;
    for (var j = 0; j <= index; j++) {
      if (!_exclus.contains(j)) n++;
    }
    return n;
  }

  List<Personnel> get _inclus {
    final res = <Personnel>[];
    for (var i = 0; i < _membres.length; i++) {
      if (!_exclus.contains(i)) res.add(_membres[i]);
    }
    return res;
  }

  int? _indexDe(Personnel p) {
    for (var i = 0; i < _membres.length; i++) {
      if (identical(_membres[i], p)) return i;
      if (p.id != null && _membres[i].id == p.id) return i;
    }
    return null;
  }

  List<Map<String, Object?>> _construireConcernes() {
    final res = <Map<String, Object?>>[];
    var n = 0;
    for (var i = 0; i < _membres.length; i++) {
      if (_exclus.contains(i)) continue;
      n++;
      res.add(concernesDepuisPersonnel(
        _membres[i],
        n,
        position: _position,
        precision: _precision,
      ));
    }
    return res;
  }

  String get _titre {
    final nom = _nom.text.trim();
    if (nom.isNotEmpty) return nom;
    return _estListe ? 'Liste' : (_position ?? 'Etat');
  }

  String? get _dureeValeur {
    final v = _duree.text.trim();
    return v.isEmpty ? null : v;
  }

  // ---------------------------------------------------------------------------
  // Proposition de liste (mode liste uniquement).
  // ---------------------------------------------------------------------------
  Future<void> _proposerListe() async {
    if (!_estListe) return;
    final ref = context.read<ReferentielProvider>();
    if (ref.categories.isEmpty) {
      try {
        await ref.charger();
      } catch (_) {}
    }
    final cats = <String>{
      for (final c in ref.categories) c.libelle,
      for (final p in _membres) categorieDe(p),
    }.toList()
      ..sort((a, b) => ordreCategorie(a).compareTo(ordreCategorie(b)));

    final totalCtrl = TextEditingController();
    final ctrlCat = <String, TextEditingController>{
      for (final c in cats) c: TextEditingController(),
    };
    var filtre = _filtreActif;

    if (!mounted) return;
    final demande = await showDialog<PropositionDemande>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Proposer une liste'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: totalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Nombre total', isDense: true),
                ),
                const SizedBox(height: 12),
                const Text('Nombre par catégorie de grade',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                for (final c in cats)
                  TextField(
                    controller: ctrlCat[c],
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: c, isDense: true),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FiltreProposition>(
                  initialValue: filtre,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Filtre', isDense: true),
                  items: [
                    for (final e in kFiltresProposition.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setDlg(() => filtre = v ?? filtre),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final total = int.tryParse(totalCtrl.text.trim()) ?? 0;
                final parCat = <String, int>{};
                ctrlCat.forEach((k, ctl) {
                  final n = int.tryParse(ctl.text.trim()) ?? 0;
                  if (n > 0) parCat[k] = n;
                });
                Navigator.pop(
                  ctx,
                  PropositionDemande(
                      total: total, parCategorie: parCat, filtre: filtre),
                );
              },
              child: const Text('Proposer'),
            ),
          ],
        ),
      ),
    );

    for (final c in ctrlCat.values) {
      c.dispose();
    }
    totalCtrl.dispose();
    if (demande == null) return;
    _appliquerProposition(demande);
  }

  void _appliquerProposition(PropositionDemande demande) {
    final choisis = proposerListe(
      membres: _membres,
      demande: demande,
      deFaction: _idsDeFaction,
    );
    if (choisis.isEmpty) {
      _snack('Aucun candidat ne correspond à la proposition.');
      return;
    }
    final ids = choisis.map((p) => p.id).whereType<int>().toSet();
    setState(() {
      _exclus.clear();
      for (var i = 0; i < _membres.length; i++) {
        final id = _membres[i].id;
        if (id == null || !ids.contains(id)) _exclus.add(i);
      }
      _propositionActive = true;
      _filtreActif = demande.filtre;
      _composition = {
        ...demande.parCategorie,
        if (demande.total > 0) 'Total': demande.total,
      };
    });
    _snack('${choisis.length} personne(s) proposée(s). Validez ou remplacez.');
  }

  void _remplacer(Personnel remplace) {
    final nouveau = remplacantPour(
      remplace: remplace,
      selection: _inclus,
      membres: _membres,
      deFaction: _idsDeFaction,
      filtre: _filtreActif,
    );
    if (nouveau == null) {
      _snack('Aucun remplaçant disponible dans la même catégorie.');
      return;
    }
    setState(() {
      final iOld = _indexDe(remplace);
      final iNew = _indexDe(nouveau);
      if (iOld != null) _exclus.add(iOld);
      if (iNew != null) _exclus.remove(iNew);
    });
  }

  // ---------------------------------------------------------------------------
  // Export / enregistrement.
  // ---------------------------------------------------------------------------
  Future<void> _exporter({required bool pdf}) async {
    if (!_estListe && _position == null) {
      _snack('Choisissez une position.');
      return;
    }
    if (_inclus.isEmpty) {
      _snack('Aucun personnel selectionne.');
      return;
    }
    final colonnes = await choisirColonnesEtat(context);
    if (colonnes == null) return;
    final concernes = _construireConcernes();
    final sousTitre = _estListe
        ? 'Liste${_dureeValeur == null ? '' : ' - Durée ${_dureeValeur!}'}'
        : '$_position${_dureeValeur == null ? '' : ' - Durée ${_dureeValeur!}'}';
    try {
      if (pdf) {
        final bytes = await PdfService.etatListe(
          _titre,
          sousTitre: sousTitre,
          concernes: concernes,
          colonnes: colonnes,
        );
        await PdfService.partager(bytes, 'etat_${_slug(_titre)}_${aujourdHui()}.pdf');
      } else {
        final path = await ExcelService.etatListe(
          _titre,
          concernes: concernes,
          colonnes: colonnes,
        );
        if (mounted) _snack('Export Excel: $path');
      }
    } catch (e) {
      if (mounted) _snack('Export impossible: $e');
    }
  }

  Future<void> _enregistrer() async {
    final nom = _nom.text.trim();
    if (nom.isEmpty) {
      _snack(_estListe ? 'Saisissez le nom de la liste.' : 'Saisissez le nom de l\'etat.');
      return;
    }
    final inclus = _inclus;
    if (inclus.isEmpty) {
      _snack('Aucun personnel selectionne.');
      return;
    }
    final concernes = _construireConcernes();
    final auth = context.read<AuthProvider>();
    final dash = context.read<DashboardProvider>();

    if (_estListe) {
      await dash.genererEtat(
        type: kTypeListe,
        nom: nom,
        duree: _dureeValeur,
        composition: _composition.isEmpty ? null : _composition,
        concernes: concernes,
        utilisateurId: auth.user?.id,
      );
      if (!mounted) return;
      _snack('Liste "$nom" enregistrée (${inclus.length} personne(s)).');
      Navigator.of(context).pop(true);
      return;
    }

    if (_position == null) {
      _snack('Choisissez une position.');
      return;
    }
    final pos = _position!;
    final precision = _precision;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier les positions ?'),
        content: Text(
          'Enregistrer l\'etat "$nom" (${inclus.length} personne(s)) ?\n\n'
          'Mettre a jour la position des personnes incluses vers "$pos"'
          '${precision == null ? '' : ' ($precision)'} ?\n'
          'Durée : ${texteDuree(_dureeValeur)}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Non')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Oui')),
        ],
      ),
    );

    await dash.genererEtat(
      type: pos,
      nom: nom,
      duree: _dureeValeur,
      concernes: concernes,
      utilisateurId: auth.user?.id,
    );

    if (confirme == true) {
      final ids = inclus.map((p) => p.id).whereType<int>().toList();
      await context.read<PersonnelProvider>().appliquerPositions(
            militaireIds: ids,
            position: pos,
            precision: precision,
            duree: _dureeValeur,
            acteur: auth.user,
          );
      if (mounted) await dash.charger();
    }

    if (!mounted) return;
    _snack(confirme == true
        ? 'Etat "$nom" enregistre et ${inclus.length} position(s) mise(s) a jour.'
        : 'Etat "$nom" enregistre (positions inchangees).');
    Navigator.of(context).pop(true);
  }

  String _slug(String texte) => texte
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('à', 'a')
      .replaceAll(' ', '_')
      .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _carteProposition() {
    final inclus = _inclus;
    return Card(
      color: Colors.blue.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: Colors.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Liste proposée (${inclus.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => setState(() => _propositionActive = false),
                  child: const Text('Fermer'),
                ),
              ],
            ),
            for (var i = 0; i < inclus.length; i++)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${i + 1}. ${inclus[i].nomPrenoms}  (${categorieDe(inclus[i])})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _remplacer(inclus[i]),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Remplacer'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_estListe ? 'Nouvelle liste' : 'Changement de position'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonalIcon(
              onPressed: _enregistrer,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _nom,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _estListe ? 'Nom de la liste *' : 'Nom de l\'etat *',
                    prefixIcon: const Icon(Icons.playlist_add),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _duree,
                  decoration: const InputDecoration(
                    labelText: 'Durée',
                    hintText: 'ex : 15 jours — vide = indéterminé',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                ),
                if (!_estListe) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _position,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Position', prefixIcon: Icon(Icons.place)),
                    items: [
                      for (final p in kPositions)
                        DropdownMenuItem(value: p, child: Text(p)),
                    ],
                    onChanged: (v) {
                      final ancien = _position;
                      setState(() {
                        if (_nom.text.trim().isEmpty || _nom.text == ancien) {
                          _nom.text = v ?? '';
                        }
                        _position = v;
                        _precision = null;
                        _appliquerPosition(v);
                      });
                      _chargerPrecisions();
                    },
                  ),
                  if (_precisions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _precision,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Precision', prefixIcon: Icon(Icons.tune)),
                      items: [
                        ..._precisions.map(
                            (p) => DropdownMenuItem(value: p, child: Text(p))),
                        const DropdownMenuItem(
                          value: _sentinelAjouter,
                          child: Text('+ AJOUTER',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == _sentinelAjouter) {
                          _ajouterPrecision();
                        } else {
                          setState(() => _precision = v);
                        }
                      },
                    ),
                  ],
                ],
                if (_estListe) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _membres.isEmpty ? null : _proposerListe,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Proposer une liste'),
                  ),
                ],
                if (_estListe && _propositionActive) ...[
                  const SizedBox(height: 12),
                  _carteProposition(),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Militaires concernes',
                        style: Theme.of(context).textTheme.titleSmall),
                    Text('${_inclus.length} / ${_membres.length}'),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _membres.isEmpty ? null : _toutSelectionner,
                      icon: const Icon(Icons.check_box_outlined, size: 18),
                      label: const Text('Tout sélectionner'),
                    ),
                    TextButton.icon(
                      onPressed: _membres.isEmpty ? null : _toutDecocher,
                      icon: const Icon(Icons.check_box_outline_blank, size: 18),
                      label: const Text('Tout décocher'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_membres.isEmpty)
                  const Card(
                      child: ListTile(title: Text('Aucun personnel.')))
                else
                  ..._membres.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    final inclus = !_exclus.contains(i);
                    return CheckboxListTile(
                      value: inclus,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _exclus.remove(i);
                        } else {
                          _exclus.add(i);
                        }
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        inclus ? '${_rang(i)}. ${p.nomPrenoms}' : p.nomPrenoms,
                        style: TextStyle(
                          fontWeight:
                              inclus ? FontWeight.w600 : FontWeight.normal,
                          decoration: inclus
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                          color: inclus ? null : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        '${p.gradeCode ?? p.gradeLibelle ?? ''} ${p.matricule ?? ''} - '
                        '${libellePosition(p.position, p.positionPrecision).isEmpty ? (p.statutLibelle ?? '') : libellePosition(p.position, p.positionPrecision)}',
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _exporter(pdf: true),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Exporter PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _exporter(pdf: false),
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Exporter Excel'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
