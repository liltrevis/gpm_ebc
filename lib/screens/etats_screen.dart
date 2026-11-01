import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/colonnes_etat.dart';
import '../core/etats.dart';
import '../core/format.dart';
import '../services/excel_service.dart';
import '../services/pdf_service.dart';
import '../services/word_service.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/referentiel_provider.dart';
import '../widgets/colonnes_etat_dialog.dart';
import 'etat_liste_screen.dart';

/// Onglet "Etats" : creation, consultation et exports (PDF / Excel).
class EtatsScreen extends StatefulWidget {
  const EtatsScreen({super.key});

  @override
  State<EtatsScreen> createState() => _EtatsScreenState();
}

class _EtatsScreenState extends State<EtatsScreen> {
  List<Map<String, Object?>> _historique = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final dash = context.read<DashboardProvider>();
    if (dash.stats.effectifTotal == 0 && !dash.loading) {
      await dash.charger();
    }
    final h = await dash.historique();
    if (mounted) setState(() => _historique = h);
  }

  Future<void> _creerEtat() async {
    final mode = await showModalBottomSheet<ModeEtat>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Créer un état',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Liste'),
              subtitle:
                  const Text('Sélection libre du personnel, avec nom de la liste'),
              onTap: () => Navigator.pop(ctx, ModeEtat.liste),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Changement de position'),
              subtitle: const Text('Conserve la configuration actuelle'),
              onTap: () => Navigator.pop(ctx, ModeEtat.position),
            ),
          ],
        ),
      ),
    );
    if (mode == null) return;
    final cree = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EtatListeScreen(mode: mode)),
    );
    if (cree == true) await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final perimetre = context.read<AuthProvider>().perimetreSectionId;
    String nomPerimetre = "Escadron";
    if (perimetre != null) {
      final ref = context.read<ReferentielProvider>();
      nomPerimetre = ref.sectionParId(perimetre)?.libelle ?? "Peloton";
    }
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (auth.peut('rapport.create'))
            FilledButton.icon(
              onPressed: _creerEtat,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Creer un etat'),
            ),
          const SizedBox(height: 12),
          Card(
            color: Colors.blue.withValues(alpha: 0.1),
            child: ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('SPA'),
              subtitle: Text(
                'Situation des Personnels Absents de $nomPerimetre\n'
                'Export PDF, Excel ou Word.',
              ),
              isThreeLine: true,
              onTap: () => _exporterSpa(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Historique de $nomPerimetre',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_historique.isEmpty)
            const Card(child: ListTile(title: Text('Aucun etat historise.')))
          else
            ..._historique.map((h) =>
                _carteEtat(h, auth.peut('rapport.export'), auth.peut('rapport.create'))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _exporterSpa() async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Exporter la SPA',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Excel'),
              onTap: () => Navigator.pop(ctx, 'excel'),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Word'),
              onTap: () => Navigator.pop(ctx, 'word'),
            ),
          ],
        ),
      ),
    );
    if (choix == null || !mounted) return;
    try {
      final data = await context.read<DashboardProvider>().spa();
      switch (choix) {
        case 'pdf':
          final bytes = await PdfService.spa(data);
          await PdfService.partager(bytes, 'spa_${aujourdHui()}.pdf');
          break;
        case 'excel':
          final path = await ExcelService.spa(data);
          if (mounted) _snack('Export Excel: $path');
          break;
        case 'word':
          final path = await WordService.spa(data);
          if (mounted) _snack('Export Word: $path');
          break;
      }
    } catch (e) {
      if (mounted) _snack('Export impossible: $e');
    }
  }

  Widget _carteEtat(Map<String, Object?> h, bool peutExport, bool peutGerer) {
    final nom = _nomListe(h);
    final concernes = _concernes(h);
    final type = etatTypeLibelle(h['type'] as String?);
    final duree = _dureeEtat(h);
    return Card(
      child: ListTile(
        leading: Icon((h['type'] as String?)?.toUpperCase() == kTypeListe
            ? Icons.checklist
            : Icons.playlist_add_check),
        title: Text(nom ?? 'Etat $type'),
        isThreeLine: true,
        subtitle: Text(
            '$type - ${afficherDateFr(h['date'] as String?)} - '
            '${concernes.length} personne(s)\n'
            'Durée : ${duree ?? "indéterminée"}'),
        onTap: concernes.isEmpty ? null : () => _voirListe(h, concernes),
        trailing: PopupMenuButton<String>(
          tooltip: 'Exporter',
          onSelected: (v) {
            if (v == 'voir') {
              _voirListe(h, concernes);
            } else if (v == 'pdf') {
              _exporterEtat(h, pdf: true);
            } else if (v == 'excel') {
              _exporterEtat(h, pdf: false);
            } else if (v == 'supprimer') {
              _supprimerEtat(h);
            }
          },
          itemBuilder: (ctx) => [
            if (concernes.isNotEmpty)
              const PopupMenuItem(value: 'voir', child: Text('Voir la liste')),
            if (peutExport)
              const PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                      dense: true,
                      leading: Icon(Icons.picture_as_pdf),
                      title: Text('Exporter PDF'))),
            if (peutExport)
              const PopupMenuItem(
                  value: 'excel',
                  child: ListTile(
                      dense: true,
                      leading: Icon(Icons.table_chart),
                      title: Text('Exporter Excel'))),
            if (peutGerer)
              const PopupMenuItem(
                  value: 'supprimer',
                  child: ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Supprimer'))),
          ],
        ),
      ),
    );
  }

  String? _dureeEtat(Map<String, Object?> h) {
    final duree = _contenu(h)?['duree'];
    return (duree is String && duree.trim().isNotEmpty) ? duree.trim() : null;
  }

  String? _nomListe(Map<String, Object?> h) {
    final data = _contenu(h);
    final nom = data?['nom'];
    return (nom is String && nom.trim().isNotEmpty) ? nom : null;
  }

  List<Map<String, Object?>> _concernes(Map<String, Object?> h) {
    final data = _contenu(h);
    final liste = data?['concernes'];
    if (liste is List) {
      return liste
          .whereType<Map>()
          .map((e) => e.cast<String, Object?>())
          .toList();
    }
    return const [];
  }

  Map<String, Object?>? _contenu(Map<String, Object?> h) {
    final raw = h['contenu_json'];
    if (raw is! String || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw);
      if (data is Map) return data.cast<String, Object?>();
    } catch (_) {}
    return null;
  }

  Future<void> _voirListe(
      Map<String, Object?> h, List<Map<String, Object?>> concernes) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_nomListe(h) ?? 'Etat ${etatTypeLibelle(h['type'] as String?)}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 0; i < concernes.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${i + 1}. ${concernes[i]['nom'] ?? ''}'
                    '${_detail(concernes[i]).isEmpty ? '' : ' (${_detail(concernes[i])})'}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer')),
        ],
      ),
    );
  }

  String _detail(Map<String, Object?> c) => positionTexte(c);

  String _titreEtat(Map<String, Object?> h) =>
      _nomListe(h) ?? 'Etat ${etatTypeLibelle(h['type'] as String?)}';

  Future<void> _exporterEtat(Map<String, Object?> h, {required bool pdf}) async {
    final concernes = _concernes(h);
    if (concernes.isEmpty) {
      _snack('Aucune donnee a exporter.');
      return;
    }
    final colonnes = await choisirColonnesEtat(context);
    if (colonnes == null) return;
    final titre = _titreEtat(h);
    final duree = _dureeEtat(h);
    try {
      if (pdf) {
        final bytes = await PdfService.etatListe(
          titre,
          sousTitre:
              '${etatTypeLibelle(h['type'] as String?)} - ${afficherDateFr(h['date'] as String?)}'
              '${duree == null ? '' : ' - Durée $duree'}',
          concernes: concernes,
          colonnes: colonnes,
        );
        await PdfService.partager(bytes, 'etat_${_slug(titre)}_${aujourdHui()}.pdf');
      } else {
        final path = await ExcelService.etatListe(
          titre,
          concernes: concernes,
          colonnes: colonnes,
        );
        if (mounted) _snack('Export Excel: $path');
      }
    } catch (e) {
      if (mounted) _snack('Export impossible: $e');
    }
  }

  Future<void> _supprimerEtat(Map<String, Object?> h) async {
    final id = h['id'] as int?;
    if (id == null) return;
    final nom = _titreEtat(h);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'etat'),
        content: Text('Supprimer definitivement l\'etat "$nom" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirme != true) return;
    final auth = context.read<AuthProvider>();
    await context.read<DashboardProvider>().supprimerEtat(
          id,
          utilisateurId: auth.user?.id,
          utilisateurNom: auth.user?.nomComplet,
        );
    if (!mounted) return;
    await _charger();
    _snack('Etat supprime.');
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
}
