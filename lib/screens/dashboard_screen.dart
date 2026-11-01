import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/autorisations.dart';
import '../core/format.dart';
import '../core/positions.dart';
import '../core/theme.dart';
import '../models/dashboard_stats.dart';
import '../providers/auth_provider.dart';
import '../providers/autorisation_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/service_provider.dart';
import '../providers/sync_provider.dart';
import '../services/excel_service.dart';
import '../services/pdf_service.dart';
import '../services/word_service.dart';
// Armement desactive
// import 'armement_screen.dart';
import 'service_form_screen.dart';

/// Ouvre l'onglet Effectifs avec un filtre optionnel.
typedef OuvrirEffectif = void Function({
  int? sectionId,
  List<String>? statutCodes,
  bool? disponible,
});

/// Tableau de bord du Commandant.
class DashboardScreen extends StatefulWidget {
  final OuvrirEffectif onOuvrirEffectif;
  final VoidCallback onOuvrirServices;

  const DashboardScreen({
    super.key,
    required this.onOuvrirEffectif,
    required this.onOuvrirServices,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Detail des rubriques developpees au choix sur une carte "Par peloton".
  final Map<int, _DetailPeloton> _detailsPeloton = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().charger();
      context.read<ServiceProvider>().chargerPositions();
      context.read<SyncProvider>().rafraichir();
    });
  }

  Future<void> _rafraichir() async {
    _detailsPeloton.clear();
    await context.read<DashboardProvider>().charger();
    await context.read<ServiceProvider>().chargerPositions();
    if (mounted) await context.read<SyncProvider>().rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final sync = context.watch<SyncProvider>();
    final auth = context.watch<AuthProvider>();
    final autorisations = context.watch<AutorisationProvider>();
    final positionsService = context.watch<ServiceProvider>().positionsService;
    final s = dash.stats;
    final enService = positionsService.values
        .where((v) => v == 'En service')
        .length;
    final deFaction = positionsService.values
        .where((v) => v == 'De faction')
        .length;

    return RefreshIndicator(
      onRefresh: _rafraichir,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (sync.enAttente > 0)
            Card(
              color: AppTheme.amber.withValues(alpha: 0.15),
              child: ListTile(
                leading: const Icon(Icons.cloud_off, color: AppTheme.amber),
                title: Text('${sync.enAttente} ecriture(s) en attente de synchronisation'),
                trailing: TextButton(
                  onPressed: sync.enCours
                      ? null
                      : () => context.read<SyncProvider>().synchroniser(),
                  child: Text(sync.enCours ? 'Envoi...' : 'Synchroniser'),
                ),
              ),
            ),
          if (dash.loading && s.effectifTotal == 0)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          const _Titre('Situation des effectifs'),
          Row(
            children: [
              Expanded(
                child: _Carte(
                  titre: 'Effectif total',
                  valeur: '${s.effectifTotal}',
                  couleur: AppTheme.slate,
                  icone: Icons.groups,
                  onTap: () => widget.onOuvrirEffectif(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Carte(
                  titre: 'Disponible',
                  valeur: '${s.disponible}',
                  couleur: AppTheme.green,
                  icone: Icons.check_circle,
                  onTap: () => widget.onOuvrirEffectif(disponible: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Carte(
                  titre: 'Indisponible',
                  valeur: '${s.indisponible}',
                  couleur: AppTheme.red,
                  icone: Icons.block,
                  onTap: () => widget.onOuvrirEffectif(disponible: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Taux de disponibilite',
                          style: Theme.of(context).textTheme.titleSmall),
                      Text('${s.tauxDisponibilite.toStringAsFixed(1)} %',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: s.effectifTotal == 0 ? 0 : s.disponible / s.effectifTotal,
                      minHeight: 10,
                      backgroundColor: AppTheme.red.withValues(alpha: 0.2),
                      color: AppTheme.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _Titre('Repartition du personnel'),
          for (final rubrique in _rubriquesRepartition)
            _blocRubrique(
              s,
              rubrique,
              enService: rubrique == 'Présent' ? enService : null,
              deFaction: rubrique == 'Présent' ? deFaction : null,
            ),
          const _Titre('Par peloton'),
          ...s.parSection.map(_cartePeloton),
          if (auth.peut('armement.read')) ...[
          // Parc d'armement desactive
          ],
          const _Titre('Actions rapides'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (auth.peut('service.read'))
                FilledButton.icon(
                  onPressed: widget.onOuvrirServices,
                  icon: const Icon(Icons.event_note),
                  label: const Text('Volet services'),
                ),
              if (auth.peut('service.create') &&
                  autorisations.autorisePour(auth.user, AutorisationCode.service))
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ServiceFormScreen()),
                    );
                    if (mounted) {
                      _detailsPeloton.clear();
                      context.read<DashboardProvider>().charger();
                      context.read<ServiceProvider>().chargerPositions();
                    }
                  },
                  icon: const Icon(Icons.add_task),
                  label: const Text('Creer un service'),
                ),
              // Armement desactive
              if (auth.peut('rapport.export'))
                FilledButton.icon(
                  onPressed: _exporterSpa,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Exporter la SPA'),
                ),
            ],
          ),
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

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _ligneStatut(
    String libelle,
    int valeur, {
    List<String>? statutCodes,
    bool? disponible,
    int? sectionId,
  }) {
    return Card(
      child: ListTile(
        dense: true,
        title: Text(libelle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$valeur',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
        onTap: () => widget.onOuvrirEffectif(
            sectionId: sectionId, statutCodes: statutCodes, disponible: disponible),
      ),
    );
  }

  static const Map<String, List<String>> _statutParRubrique = {
    'Présent': ['EN_SERVICE'],
    'Mission': ['EN_MISSION'],
    'Stage': ['EN_STAGE'],
    'Mise a disposition': ['MISE_A_DISPOSITION'],
    'Permission': ['EN_PERMISSION', 'EN_CONGE'],
    'Malade': ['MALADE'],
    'Repos': ['REPOS_MEDICAL'],
    'Absent': ['ABSENT'],
  };

  /// Rubriques de repartition du personnel, dans l'ordre d'affichage
  /// (partagees par le tableau global et le detail d'un peloton).
  static const List<String> _rubriquesRepartition = [
    'Présent',
    'Mission',
    'Stage',
    'Mise a disposition',
    'Permission',
    'Malade',
    'Repos',
    'Absent',
  ];

  /// Bloc d'une position principale : simple s'il n'y a pas de detail,
  /// sinon une liste deroulante revelant les precisions imbriquees ainsi
  /// que, pour "Present", les rubriques "En service" et "De faction"
  /// (imbiqquees dans "Present" et developpees si besoin).
  Widget _blocRubrique(
    DashboardStats stats,
    String rubrique, {
    int? sectionId,
    int? enService,
    int? deFaction,
  }) {
    final r = stats.rubrique(rubrique);
    final total = r?.total ?? 0;
    final codes = _statutParRubrique[rubrique];
    final precisions = r?.precisions ?? const <PrecisionStats>[];
    final detaillees =
        precisions.where((p) => p.libelle != 'Sans précision').toList();
    final imbriquee = enService != null && deFaction != null;
    if (detaillees.isEmpty && !imbriquee) {
      return _ligneStatut(rubrique, total,
          statutCodes: codes, sectionId: sectionId);
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: EdgeInsets.zero,
          title: Text('$rubrique  ($total)'),
          children: [
            for (final p in precisions) _lignePrecision(p),
            if (imbriquee) ...[
              _ligneSousRubrique('En service (astreinte)', enService,
                  Icons.workspaces_outline, AppTheme.green),
              _ligneSousRubrique('De faction', deFaction, Icons.shield,
                  AppTheme.amber),
            ],
            if (codes != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => widget.onOuvrirEffectif(
                      sectionId: sectionId, statutCodes: codes),
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('Voir dans les effectifs'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Precision imbriquee : depliable vers les personnes concernees.
  Widget _lignePrecision(PrecisionStats p) {
    return ExpansionTile(
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 28),
      title: Text('${p.libelle}  (${p.total})'),
      children: [
        for (final pers in p.personnes)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 44, right: 16),
            title: Text(pers.nom),
            subtitle: Text(resumePosition(pers.debut, pers.duree)),
          ),
      ],
    );
  }

  /// Sous-rubrique imbriquee (dans "Present") : En service / De faction.
  Widget _ligneSousRubrique(
      String libelle, int valeur, IconData icone, Color couleur) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      leading: Icon(icone, color: couleur, size: 18),
      title: Text(libelle, style: const TextStyle(fontSize: 13)),
      trailing: Text('$valeur',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15, color: couleur)),
    );
  }

  /// Carte d'un peloton, developpee au choix pour reveler les memes
  /// rubriques de repartition du personnel que le tableau global.
  Widget _cartePeloton(SectionStats st) {
    final detail = _detailsPeloton[st.sectionId];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text('${st.effectif}')),
          title: Text(st.libelle),
          subtitle: Text('${st.disponible} disponible(s)'),
          onExpansionChanged: (ouvert) {
            if (ouvert) _chargerDetailPeloton(st.sectionId);
          },
          children: [
            if (detail == null || detail.chargement)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (detail.stats != null) ...[
              for (final rubrique in _rubriquesRepartition)
                _blocRubrique(
                  detail.stats!,
                  rubrique,
                  sectionId: st.sectionId,
                  enService: rubrique == 'Présent' ? detail.enService : null,
                  deFaction:
                      rubrique == 'Présent' ? detail.deFaction : null,
                ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    widget.onOuvrirEffectif(sectionId: st.sectionId),
                icon: const Icon(Icons.list_alt, size: 18),
                label: const Text('Voir dans les effectifs'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Charge une seule fois le detail des rubriques d'un peloton
  /// (developpement au choix de sa carte).
  Future<void> _chargerDetailPeloton(int sectionId) async {
    final detail = _detailsPeloton.putIfAbsent(sectionId, _DetailPeloton.new);
    if (detail.chargement || detail.stats != null) return;
    detail.chargement = true;
    setState(() {});
    try {
      final stats =
          await context.read<DashboardProvider>().detailSection(sectionId);
      final positions =
          await context.read<ServiceProvider>().positionsServiceDe(sectionId);
      detail.stats = stats;
      detail.enService =
          positions.values.where((v) => v == 'En service').length;
      detail.deFaction =
          positions.values.where((v) => v == 'De faction').length;
    } finally {
      detail.chargement = false;
      if (mounted) setState(() {});
    }
  }
}

class _Titre extends StatelessWidget {
  final String texte;
  const _Titre(this.texte);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(texte, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Detail charge a la demande pour la carte d'un peloton.
class _DetailPeloton {
  DashboardStats? stats;
  int enService = 0;
  int deFaction = 0;
  bool chargement = false;
}

class _Carte extends StatelessWidget {
  final String titre;
  final String valeur;
  final Color couleur;
  final IconData icone;
  final VoidCallback? onTap;

  const _Carte({
    required this.titre,
    required this.valeur,
    required this.couleur,
    required this.icone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: couleur),
              const SizedBox(height: 8),
              Text(valeur,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: couleur)),
              Text(titre),
            ],
          ),
        ),
      ),
    );
  }
}
