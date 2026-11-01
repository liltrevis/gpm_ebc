import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/service.dart';
import '../providers/auth_provider.dart';
import '../providers/referentiel_provider.dart';
import '../providers/service_provider.dart';
import 'service_poste_screen.dart';

/// Creation d'un service : renseignement (date, type, heure de debut, duree
/// 24h/48h) puis passage a la creation du poste principal, avant validation
/// dans l'onglet Service. La fin est calculee automatiquement (debut + duree).
class ServiceFormScreen extends StatefulWidget {
  /// Service à modifier, ou null pour une création.
  final ServiceModel? service;
  const ServiceFormScreen({super.key, this.service});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  String _date = aujourdHui();
  int? _typeServiceId;
  final _debut = TextEditingController(text: '06:00');
  final _nom = TextEditingController();
  int _duree = 24;
  bool _chargement = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    if (s != null) {
      _date = s.date;
      _typeServiceId = s.typeServiceId;
      _debut.text = s.creneauDebut ?? '06:00';
      _nom.text = s.libelle ?? '';
      _duree = s.dureeHeures;
    }
  }

  @override
  void dispose() {
    _debut.dispose();
    _nom.dispose();
    super.dispose();
  }

  /// Vrai si le type selectionne est "Autre service" (nom libre obligatoire).
  bool _typeAutre(ReferentielProvider ref) =>
      _typeServiceId != null &&
      ref.typesService.any((e) => e.id == _typeServiceId && e.code == 'AUTRE');

  /// Debut du service (date + heure de debut) ou null si invalide.
  DateTime? get _debutDt {
    final jour = DateTime.tryParse(_date);
    final minutes = _minutesDepuis(_debut.text);
    if (jour == null || minutes == null) return null;
    return DateTime(jour.year, jour.month, jour.day)
        .add(Duration(minutes: minutes));
  }

  /// Fin du service (debut + duree).
  DateTime? get _finDt => _debutDt?.add(Duration(hours: _duree));

  static int? _minutesDepuis(String s) {
    final v = s.trim().replaceAll(RegExp('[hH]'), ':');
    if (v.isEmpty) return null;
    final parts = v.split(':');
    final h = int.tryParse(parts[0]);
    if (h == null || h < 0 || h > 23) return null;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    if (m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ref = context.watch<ReferentielProvider>();
    final fin = _finDt;
    final typeAutre = _typeAutre(ref);
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.service == null
              ? 'Créer un service'
              : 'Modifier le service')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Renseigner le service',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Date'),
            subtitle: Text(_dateFr(_date)),
            trailing: const Icon(Icons.edit_calendar),
            onTap: _choisirDate,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _typeServiceId,
            decoration: const InputDecoration(
                labelText: 'Type de service', border: OutlineInputBorder()),
            items: ref.typesService
                .map((e) => DropdownMenuItem(value: e.id, child: Text(e.libelle)))
                .toList(),
            onChanged: (v) => setState(() => _typeServiceId = v),
          ),
          if (typeAutre) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _nom,
              decoration: const InputDecoration(
                  labelText: 'Nom du service',
                  hintText: 'Nommer le service',
                  border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _debut,
            decoration: const InputDecoration(
                labelText: 'Heure de début (HH:MM)', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('Durée de service', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 24, label: Text('24h')),
              ButtonSegment(value: 48, label: Text('48h')),
            ],
            selected: {_duree},
            onSelectionChanged: (s) => setState(() => _duree = s.first),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Fin du service (calculée)'),
              subtitle: Text(fin == null
                  ? 'Heure de début invalide.'
                  : '${_dateFr(_ymd(fin))}  ${_hm(fin)}'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _chargement ? null : _enregistrer,
            icon: Icon(widget.service == null
                ? Icons.account_tree_outlined
                : Icons.save),
            label: Text(widget.service == null
                ? 'Créer un poste principal'
                : 'Enregistrer les modifications'),
          ),
        ],
      ),
    );
  }

  String _dateFr(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return ymd;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = _ymd(d));
  }

  bool _valide() {
    if (_typeServiceId == null) {
      _snack('Le type de service est obligatoire.');
      return false;
    }
    if (_typeAutre(context.read<ReferentielProvider>()) &&
        _nom.text.trim().isEmpty) {
      _snack('Le nom du service est obligatoire.');
      return false;
    }
    if (_debutDt == null) {
      _snack('Heure de début invalide (HH:MM).');
      return false;
    }
    return true;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  ServiceModel _saisie(ServiceModel? base) {
    final debut = _debutDt!;
    final fin = debut.add(Duration(hours: _duree));
    final typeAutre = _typeAutre(context.read<ReferentielProvider>());
    return ServiceModel(
      id: base?.id,
      date: _ymd(debut),
      creneauDebut: _hm(debut),
      creneauFin: _hm(fin),
      dureeHeures: _duree,
      dateFin: _ymd(fin),
      typeServiceId: _typeServiceId,
      libelle: typeAutre ? _nom.text.trim() : null,
      statut: base?.statut ?? 'PLANIFIE',
      origine: base?.origine ?? 'MANUEL',
    );
  }

  Future<void> _enregistrer() async {
    if (!_valide()) return;
    setState(() => _chargement = true);
    final prov = context.read<ServiceProvider>();
    final auth = context.read<AuthProvider>();
    if (widget.service != null) {
      await prov.modifierService(_saisie(widget.service), acteur: auth.user);
      if (!mounted) return;
      setState(() => _chargement = false);
      Navigator.of(context).pop(true);
      return;
    }
    final cree = await prov.creer(_saisie(null), const [], acteur: auth.user);
    if (!mounted) return;
    setState(() => _chargement = false);
    if (cree == null) {
      _snack('Création du service impossible.');
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ServicePosteScreen(service: cree)),
    );
  }
}
