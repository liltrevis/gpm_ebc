import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/arme.dart';
import '../models/personnel.dart';
import '../providers/armement_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/personnel_provider.dart';

/// Enregistrement d'un mouvement d'armurerie (sortie / entree).
class MouvementFormScreen extends StatefulWidget {
  const MouvementFormScreen({super.key});

  @override
  State<MouvementFormScreen> createState() => _MouvementFormScreenState();
}

class _MouvementFormScreenState extends State<MouvementFormScreen> {
  String _sens = 'SORTIE';
  String _cible = 'ARME';
  int? _armeId;
  int? _munitionId;
  int _quantite = 1;
  int? _beneficiaireId;
  String? _motif = MotifMouvement.garde;
  final _reference = TextEditingController();

  List<Personnel> _disponibles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final arm = context.read<ArmementProvider>();
      final pers = context.read<PersonnelProvider>();
      if (arm.armes.isEmpty) await arm.charger();
      _disponibles = await pers.disponibles();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arm = context.watch<ArmementProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Mouvement d\'armurerie')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'SORTIE', label: Text('Sortie')),
              ButtonSegment(value: 'ENTREE', label: Text('Entree')),
            ],
            selected: {_sens},
            onSelectionChanged: (s) => setState(() => _sens = s.first),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ARME', label: Text('Arme')),
              ButtonSegment(value: 'MUNITION', label: Text('Munition')),
            ],
            selected: {_cible},
            onSelectionChanged: (s) => setState(() => _cible = s.first),
          ),
          const SizedBox(height: 12),
          if (_cible == 'ARME')
            DropdownButtonFormField<int>(
              value: _armeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Arme (numero de serie)'),
              items: arm.armes
                  .map((a) => DropdownMenuItem(value: a.id, child: Text(a.numeroSerie)))
                  .toList(),
              onChanged: (v) => setState(() => _armeId = v),
            )
          else ...[
            DropdownButtonFormField<int>(
              value: _munitionId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Munition'),
              items: arm.munitions
                  .map((m) => DropdownMenuItem(value: m.id, child: Text(m.designation)))
                  .toList(),
              onChanged: (v) => setState(() => _munitionId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: '$_quantite',
              decoration: const InputDecoration(labelText: 'Quantite'),
              keyboardType: TextInputType.number,
              onChanged: (v) => _quantite = int.tryParse(v) ?? 1,
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _beneficiaireId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Beneficiaire (militaire)'),
            items: _disponibles
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nomPrenoms)))
                .toList(),
            onChanged: (v) => setState(() => _beneficiaireId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _motif,
            decoration: const InputDecoration(labelText: 'Motif'),
            items: const [
              DropdownMenuItem(value: MotifMouvement.garde, child: Text('Garde')),
              DropdownMenuItem(value: MotifMouvement.instruction, child: Text('Instruction')),
              DropdownMenuItem(value: MotifMouvement.tir, child: Text('Tir')),
              DropdownMenuItem(value: MotifMouvement.operation, child: Text('Operation')),
              DropdownMenuItem(value: MotifMouvement.inventaire, child: Text('Inventaire')),
            ],
            onChanged: (v) => setState(() => _motif = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reference,
            decoration: const InputDecoration(labelText: 'Reference ordre (facultatif)'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _enregistrer,
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer le mouvement'),
          ),
        ],
      ),
    );
  }

  Future<void> _enregistrer() async {
    if (_cible == 'ARME' && _armeId == null) {
      _erreur('Selectionnez une arme.');
      return;
    }
    if (_cible == 'MUNITION' && _munitionId == null) {
      _erreur('Selectionnez une munition.');
      return;
    }
    final prov = context.read<ArmementProvider>();
    final auth = context.read<AuthProvider>();
    final m = Mouvement(
      sens: _sens,
      armeId: _cible == 'ARME' ? _armeId : null,
      munitionId: _cible == 'MUNITION' ? _munitionId : null,
      quantite: _cible == 'MUNITION' ? _quantite : 1,
      dateHeure: DateTime.now().toIso8601String(),
      motif: _motif,
      referenceOrdre: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
      beneficiaireId: _beneficiaireId,
      statutValidation: 'ENREGISTRE',
    );
    await prov.enregistrerMouvement(m, acteur: auth.user);
    if (mounted) Navigator.of(context).pop();
  }

  void _erreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
