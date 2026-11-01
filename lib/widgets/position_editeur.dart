import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/autorisations.dart';
import '../core/positions.dart';
import '../core/theme.dart';
import '../models/personnel.dart';
import '../providers/auth_provider.dart';
import '../providers/autorisation_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/personnel_provider.dart';
import '../providers/referentiel_provider.dart';
import '../providers/service_provider.dart';

/// Vrai si l'utilisateur a le droit de modifier une position : droit RBAC
/// (personnel.update ou statut.update) et, pour un chef de peloton,
/// autorisation du Commandant Escadron.
bool peutModifierPosition(AuthProvider auth, AutorisationProvider autorisations) {
  final droit = auth.peut('personnel.update') || auth.peut('statut.update');
  return droit && autorisations.autorisePour(auth.user, AutorisationCode.statut);
}

/// Sentinelle de l'option "AJOUTER" du menu de precision.
const String _sentinelAjouter = '__AJOUTER__';

/// Valeur renvoyee par le selecteur : position (rubrique) + precision +
/// date/heure de debut (ISO, facultative) + duree libre (facultative).
class ChoixPosition {
  final String position;
  final String? precision;
  final String? debut;
  final String? duree;
  const ChoixPosition(this.position, this.precision, {this.debut, this.duree});
}

/// Ouvre le selecteur de position et applique le changement immediatement.
/// Retourne true si la position a ete modifiee.
Future<bool> ouvrirSelecteurPosition(
  BuildContext context,
  Personnel personnel,
) async {
  if (personnel.id == null) return false;
  final auth = context.read<AuthProvider>();
  final autorisations = context.read<AutorisationProvider>();
  final droit = auth.peut('personnel.update') || auth.peut('statut.update');
  if (!droit) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modification non autorisee.')),
    );
    return false;
  }
  if (!autorisations.autorisePour(auth.user, AutorisationCode.statut)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Autorisation du commandant escadron requise.'),
      ),
    );
    return false;
  }

  final choix = await showModalBottomSheet<ChoixPosition>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _PositionPicker(
      actuelle: personnel.position,
      precisionActuelle: personnel.positionPrecision,
      debutActuel: personnel.positionDebut,
      dureeActuelle: personnel.positionDuree,
    ),
  );
  if (choix == null) return false;
  if (!context.mounted) return false;
  final nouvelle = choix.position.trim();
  final precision = choix.precision?.trim();
  final debut = choix.debut?.trim();
  final duree = choix.duree?.trim();
  final libelle =
      nouvelle.isEmpty ? 'Aucune' : libellePosition(nouvelle, precision);
  final inchange = nouvelle == (personnel.position ?? '').trim() &&
      (precision ?? '') == (personnel.positionPrecision ?? '').trim() &&
      (debut ?? '') == (personnel.positionDebut ?? '').trim() &&
      (duree ?? '') == (personnel.positionDuree ?? '').trim();
  if (inchange) return false;

  final confirme = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirmation'),
      content: Text(
          'Confirmer le changement de position de ${personnel.nomPrenoms} '
          'vers "$libelle" ?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmer')),
      ],
    ),
  );
  if (confirme != true) return false;
  if (!context.mounted) return false;

  final prov = context.read<PersonnelProvider>();
  final dashboard = context.read<DashboardProvider>();
  await prov.changerPosition(
    militaireId: personnel.id!,
    position: nouvelle.isEmpty ? null : nouvelle,
    precision: precision,
    debut: debut,
    duree: duree,
    acteur: auth.user,
  );
  await dashboard.charger();
  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Position : $libelle')),
  );
  return true;
}

class _PositionPicker extends StatefulWidget {
  final String? actuelle;
  final String? precisionActuelle;
  final String? debutActuel;
  final String? dureeActuelle;
  const _PositionPicker({
    required this.actuelle,
    this.precisionActuelle,
    this.debutActuel,
    this.dureeActuelle,
  });

  @override
  State<_PositionPicker> createState() => _PositionPickerState();
}

class _PositionPickerState extends State<_PositionPicker> {
  String? _choix;
  String? _precision;
  DateTime? _debut;
  late final TextEditingController _duree;
  List<String> _optionsList = [];
  int _reset = 0;

  @override
  void initState() {
    super.initState();
    final a = widget.actuelle?.trim();
    _choix = (a != null && kPositions.contains(a)) ? a : null;
    final p = widget.precisionActuelle?.trim();
    if (p != null && p.isNotEmpty) _precision = p;
    _debut = DateTime.tryParse(widget.debutActuel?.trim() ?? '');
    _duree = TextEditingController(text: widget.dureeActuelle?.trim() ?? '');
    _chargerOptions();
  }

  @override
  void dispose() {
    _duree.dispose();
    super.dispose();
  }

  Future<void> _choisirDebut() async {
    final base = _debut ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final heure = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (heure == null || !mounted) return;
    setState(() {
      _debut = DateTime(date.year, date.month, date.day, heure.hour,
          heure.minute);
    });
  }

  Future<void> _chargerOptions() async {
    final pos = _choix;
    if (pos == null) return;
    final base = precisionsPourPosition(pos);
    List<String> depuisDb = <String>[];
    try {
      depuisDb =
          await context.read<ReferentielProvider>().precisionsPosition(pos);
    } catch (_) {}
    if (!mounted) return;
    final liste = <String>[...base];
    for (final e in depuisDb) {
      if (!liste.contains(e)) liste.add(e);
    }
    setState(() {
      _optionsList = liste;
    });
  }

  List<String> _options() {
    final liste = [..._optionsList];
    final p = _precision;
    if (p != null && p.isNotEmpty && !liste.contains(p)) liste.add(p);
    return liste;
  }

  Future<void> _ajouterPrecision() async {
    final pos = _choix;
    if (pos == null) return;
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
    if (valeur.isEmpty) {
      if (mounted) setState(() => _reset++);
      return;
    }
    try {
      await context
          .read<ReferentielProvider>()
          .ajouterPrecisionPosition(position: pos, libelle: valeur);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      if (!_optionsList.contains(valeur)) _optionsList.add(valeur);
      _precision = valeur;
      _reset++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = precisionsPourPosition(_choix);
    final options = _options();
    final valide = _choix != null && (base.isEmpty || _precision != null);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Position', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
              'Actuelle : ${widget.actuelle?.trim().isNotEmpty == true ? libellePosition(widget.actuelle, widget.precisionActuelle) : 'Aucune'}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _choix,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Choisir une position', prefixIcon: Icon(Icons.list)),
            items: kPositions
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) {
              setState(() {
                _choix = v;
                _precision = null;
                _reset++;
              });
              _chargerOptions();
            },
          ),
          if (base.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('prec-$_choix-$_reset'),
              initialValue: _precision,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Precision', prefixIcon: Icon(Icons.tune)),
              items: [
                ...options.map(
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
                  setState(() {
                    _precision = v;
                    _reset++;
                  });
                }
              },
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Début : ${texteDebut(_debut?.toIso8601String())}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _choisirDebut,
                icon: const Icon(Icons.event, size: 18),
                label: const Text('Choisir'),
              ),
              if (_debut != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Indéterminé',
                  onPressed: () => setState(() => _debut = null),
                ),
            ],
          ),
          TextField(
            controller: _duree,
            decoration: const InputDecoration(
              labelText: 'Durée',
              hintText: 'ex. 48h, 3 jours (vide = indéterminé)',
              prefixIcon: Icon(Icons.hourglass_bottom),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: !valide
                    ? null
                    : () => Navigator.of(context).pop(ChoixPosition(
                          _choix!,
                          base.isEmpty ? null : _precision,
                          debut: _debut?.toIso8601String(),
                          duree: _duree.text.trim().isEmpty
                              ? null
                              : _duree.text.trim(),
                        )),
                child: const Text('Valider'),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

/// Puce compacte et cliquable affichant la position (onglet Effectifs).
class PositionChip extends StatelessWidget {
  final Personnel personnel;
  final VoidCallback? onChanged;
  const PositionChip({super.key, required this.personnel, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final autorisations = context.watch<AutorisationProvider>();
    final modifiable = peutModifierPosition(auth, autorisations);
    final nonVide = personnel.position?.trim().isNotEmpty == true;
    final texte =
        nonVide ? libellePosition(personnel.position, personnel.positionPrecision) : 'Aucune';
    return Tooltip(
      message: resumePosition(personnel.positionDebut, personnel.positionDuree),
      child: InkWell(
      onTap: modifiable
          ? () async {
              final ok = await ouvrirSelecteurPosition(context, personnel);
              if (ok) onChanged?.call();
            }
          : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.slate.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place,
                size: 13, color: nonVide ? AppTheme.slate : Colors.grey),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                texte,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            if (modifiable) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 16),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

/// Badge « En service » / « De faction » derive du service d'astreinte en
/// cours. Ne s'affiche que si le militaire est concerne.
class PositionServiceChip extends StatelessWidget {
  final int? militaireId;
  const PositionServiceChip({super.key, this.militaireId});

  @override
  Widget build(BuildContext context) {
    final precision =
        context.watch<ServiceProvider>().positionService(militaireId);
    if (precision == null) return const SizedBox.shrink();
    final faction = precision == 'De faction';
    final couleur = faction ? AppTheme.amber : AppTheme.green;
    final icone = faction ? Icons.shield : Icons.workspaces_outline;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: couleur.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 13, color: couleur),
            const SizedBox(width: 4),
            Text(
              precision,
              style: TextStyle(
                  fontSize: 11,
                  color: couleur,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne « Position » de la fiche (label + valeur cliquable).
class PositionLigne extends StatelessWidget {
  final Personnel personnel;
  final VoidCallback? onChanged;
  const PositionLigne({super.key, required this.personnel, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final autorisations = context.watch<AutorisationProvider>();
    final modifiable = peutModifierPosition(auth, autorisations);
    final nonVide = personnel.position?.trim().isNotEmpty == true;
    final texte = nonVide
        ? libellePosition(personnel.position, personnel.positionPrecision)
        : '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 130,
                child:
                    Text('Position', style: TextStyle(color: AppTheme.slate)),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: modifiable
                        ? () async {
                            final ok = await ouvrirSelecteurPosition(
                                context, personnel);
                            if (ok) onChanged?.call();
                          }
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.slate.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(texte)),
                          if (modifiable) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (nonVide)
            Padding(
              padding: const EdgeInsets.only(left: 130, top: 2),
              child: Text(
                resumePosition(
                    personnel.positionDebut, personnel.positionDuree),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}