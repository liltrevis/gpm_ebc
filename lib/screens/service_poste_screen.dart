import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/autorisations.dart';
import '../models/app_user.dart';
import '../models/referentiel.dart';
import '../models/service.dart';
import '../providers/auth_provider.dart';
import '../providers/autorisation_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/personnel_provider.dart';
import '../providers/referentiel_provider.dart';
import '../providers/service_provider.dart';
import '../services/excel_service.dart';
import '../services/pdf_service.dart';
import '../services/word_service.dart';

/// Gestion des postes d'un service : postes principaux (chef + adjoint +
/// postes basiques garnis par une faction) et roles propres a l'astreinte.
class ServicePosteScreen extends StatefulWidget {
  final ServiceModel service;
  const ServicePosteScreen({super.key, required this.service});

  @override
  State<ServicePosteScreen> createState() => _ServicePosteScreenState();
}

class _ServicePosteScreenState extends State<ServicePosteScreen> {
  bool _chargement = true;
  List<ServicePoste> _principaux = [];
  List<ServiceRole> _roles = [];
  List<ServiceQrf> _qrfs = [];
  List<MilitaireOption> _militaires = [];

  int get _serviceId => widget.service.id!;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final prov = context.read<ServiceProvider>();
    if (widget.service.estAstreinte) {
      await prov.assurerRolesParDefaut(_serviceId);
    }
    final plats = await prov.postes(_serviceId);
    final roles = await prov.roles(_serviceId);
    final qrfs =
        widget.service.estAstreinte ? await prov.qrfs(_serviceId) : <ServiceQrf>[];
    final mils = await prov.militaires();
    if (!mounted) return;
    setState(() {
      _principaux = ServicePoste.arborescence(plats);
      _roles = roles;
      _qrfs = qrfs;
      _militaires = mils;
      _chargement = false;
    });
    await _rafraichirOngletsLies();
  }

  /// Rafraichit les autres onglets impactes par les changements de service
  /// (Effectifs et Tableau de bord : positions derivees "En service" /
  /// "De faction").
  Future<void> _rafraichirOngletsLies() async {
    if (!mounted) return;
    await context.read<PersonnelProvider>().charger();
    if (!mounted) return;
    await context.read<DashboardProvider>().charger();
    if (!mounted) return;
    await prov.chargerPositions();
  }

  ServiceProvider get prov => context.read<ServiceProvider>();

  Future<void> _recharger() => _charger();

  /// Recharge le service puis confirme le changement par un message.
  Future<void> _rafraichirEtConfirmer(
      [String message = 'Modification enregistrée.']) async {
    await _recharger();
    if (mounted) _snack(message);
  }

  Future<void> _exporter() async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Exporter la composition de l\'astreinte')),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on),
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
    final data = AstreinteData(
      service: widget.service,
      principaux: _principaux,
      roles: _roles,
      qrfs: _qrfs,
    );
    try {
      switch (choix) {
        case 'pdf':
          final bytes = await PdfService.astreinte(data);
          await PdfService.partager(
              bytes, 'astreinte_${widget.service.date}.pdf');
          break;
        case 'excel':
          final path = await ExcelService.astreinte(data);
          if (mounted) _snack('Export Excel: $path');
          break;
        case 'word':
          final path = await WordService.astreinte(data);
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

  Set<int> get _affectes {
    final s = <int>{};
    void ajouter(List<AffectationService> liste) {
      for (final a in liste) {
        if (a.militaireId != null) s.add(a.militaireId!);
      }
    }

    for (final p in _principaux) {
      ajouter(p.affectations);
      for (final e in p.enfants) {
        ajouter(e.affectations);
      }
    }
    for (final r in _roles) {
      ajouter(r.affectations);
    }
    for (final q in _qrfs) {
      for (final m in q.membres) {
        if (m.militaireId != null) s.add(m.militaireId!);
      }
    }
    return s;
  }

  bool get _peutModifier {
    final auth = context.read<AuthProvider>();
    return auth.peut('service.create') &&
        context
            .read<AutorisationProvider>()
            .autorisePour(auth.user, AutorisationCode.service);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.service.nom),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exporter la composition',
            onPressed: _principaux.isEmpty && _roles.isEmpty && _qrfs.isEmpty
                ? null
                : _exporter,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
                '${widget.service.date}  ${widget.service.creneauDebut ?? ''}-${widget.service.creneauFin ?? ''}  (${widget.service.dureeHeures}h)',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  _entete('Postes principaux'),
                  ..._principaux.map(_cartePostePrincipal),
                  if (_principaux.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Aucun poste principal pour ce service.'),
                    ),
                  if (_peutModifier)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: OutlinedButton.icon(
                        onPressed: _creerPostePrincipal,
                        icon: const Icon(Icons.add),
                        label: const Text('Créer un poste principal'),
                      ),
                    ),
                  if (widget.service.estAstreinte) ...[
                    _entete("Rôles de l'astreinte"),
                    ..._roles.map(_carteRole),
                    if (_peutModifier)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: OutlinedButton.icon(
                          onPressed: _creerRole,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un rôle'),
                        ),
                      ),
                    _entete('QRF'),
                    ..._qrfs.map(_carteQrf),
                    if (_qrfs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Aucune QRF pour ce service.'),
                      ),
                    if (_peutModifier)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: OutlinedButton.icon(
                          onPressed: _ajouterQrf,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter une QRF'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _barreValidation(),
    );
  }

  Widget? _barreValidation() {
    if (!_peutModifier) return null;
    final peutValider = context.read<AuthProvider>().peut('service.validate');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _validerEtEnregistrer,
            icon: const Icon(Icons.verified),
            label: Text(peutValider
                ? 'Valider et enregistrer'
                : 'Enregistrer dans l\'onglet Service'),
          ),
        ),
      ),
    );
  }

  Future<void> _validerEtEnregistrer() async {
    final auth = context.read<AuthProvider>();
    final prov = context.read<ServiceProvider>();
    if (auth.peut('service.validate')) {
      await prov.valider(_serviceId, acteur: auth.user);
    } else {
      await prov.charger();
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _entete(String titre) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(titre, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _cartePostePrincipal(ServicePoste poste) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.account_tree_outlined),
        title: Text(poste.libelle),
        subtitle: Text('${poste.enfants.length} poste(s) basique(s)'),
        trailing: _peutModifier
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _supprimerPoste(poste),
              )
            : null,
        children: [
          _ligneTitulaire(poste, 'CHEF_POSTE', 'Chef de poste', poste.chef),
          _ligneTitulaire(poste, 'ADJOINT', 'Adjoint', poste.adjoint),
          const Divider(height: 1),
          for (final basique in poste.enfants) _blocPosteBasique(basique),
          if (_peutModifier)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _creerPosteBasique(poste),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter un poste basique'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ligneTitulaire(
      ServicePoste poste, String role, String libelle, AffectationService? titulaire) {
    final cible = role == 'CHEF_POSTE' ? CibleGrade.chef : CibleGrade.adjoint;
    final grades = poste.gradesPour(cible);
    return ListTile(
      dense: true,
      leading: const Icon(Icons.person_outline, size: 20),
      title: Text(libelle),
      subtitle: Text(
          '${titulaire?.nomAffichage ?? 'Non désigné'}\nGrades: ${_gradesTexte(grades)}'),
      isThreeLine: true,
      trailing: _peutModifier
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.military_tech, size: 20),
                  tooltip: 'Grades autorisés',
                  onPressed: () => _editerGradesPoste(poste, cible, libelle),
                ),
                IconButton(
                  icon: Icon(titulaire == null ? Icons.add : Icons.swap_horiz,
                      size: 20),
                  tooltip: titulaire == null ? 'Désigner' : 'Remplacer',
                  onPressed: () => _affecterTitulaire(poste, role),
                ),
              ],
            )
          : null,
    );
  }

  Widget _blocPosteBasique(ServicePoste basique) {
    final faction = basique.faction;
    final effectif = basique.effectifRequis;
    final creneaux = (widget.service.estAstreinte &&
            widget.service.debutDt != null &&
            faction.isNotEmpty)
        ? creneauxFaction2h(
            debut: widget.service.debutDt!,
            dureeHeures: widget.service.dureeHeures,
            faction: faction,
          )
        : const <CreneauFaction>[];
    final maintenant = DateTime.now();
    final actifId = creneaux
        .cast<CreneauFaction?>()
        .firstWhere(
          (c) => !maintenant.isBefore(c!.debut) && maintenant.isBefore(c.fin),
          orElse: () => null,
        )
        ?.affectation
        ?.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  effectif == null
                      ? basique.libelle
                      : '${basique.libelle}  (${faction.length}/$effectif)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (basique.creneauDebut != null || basique.creneauFin != null)
                Text('${basique.creneauDebut ?? ''}-${basique.creneauFin ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall),
              if (_peutModifier)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _supprimerPoste(basique),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text('Grades: ${_gradesTexte(basique.gradesFaction)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              if (_peutModifier)
                IconButton(
                  icon: const Icon(Icons.military_tech, size: 18),
                  tooltip: 'Grades autorisés',
                  onPressed: () => _editerGradesPoste(
                      basique, CibleGrade.faction, basique.libelle),
                ),
            ],
          ),
          if (!basique.complet && effectif != null)
            Text('Effectif incomplet', style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: faction
                .map((a) {
                  final enFaction = a.id != null && a.id == actifId;
                  return Chip(
                    label: Text(a.nomAffichage,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: enFaction ? FontWeight.bold : null,
                        )),
                    avatar: enFaction
                        ? Icon(Icons.shield,
                            size: 16, color: Colors.green.shade800)
                        : null,
                    backgroundColor: enFaction ? Colors.green.shade100 : null,
                    visualDensity: VisualDensity.compact,
                    onDeleted: _peutModifier ? () => _retirer(a) : null,
                  );
                })
                .toList(),
          ),
          if (widget.service.estAstreinte &&
              widget.service.debutDt != null &&
              faction.isNotEmpty) ...[
            const SizedBox(height: 6),
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                dense: true,
                title: Text(
                  'Historique des factions (2h, boucle sur ${widget.service.dureeHeures}h)',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                children: creneaux.map((c) {
                  final enFaction = !maintenant.isBefore(c.debut) &&
                      maintenant.isBefore(c.fin);
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: enFaction
                          ? BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            )
                          : null,
                      child: Text(
                        '${hm(c.debut)}-${hm(c.fin)}  ${c.affectation?.nomAffichage ?? ''}'
                        '${enFaction ? '  (en faction maintenant)' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: enFaction ? FontWeight.bold : null,
                              color: enFaction ? Colors.green.shade900 : null,
                            ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (_peutModifier)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _ajouterFaction(basique),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Garnir la faction'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _carteRole(ServiceRole role) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${role.libelle}  (${role.affectations.length}/${role.nombreRequis})',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (_peutModifier)
                  IconButton(
                    icon: const Icon(Icons.military_tech, size: 18),
                    tooltip: 'Grades autorisés',
                    onPressed: () => _editerGradesRole(role),
                  ),
                if (_peutModifier)
                  IconButton(
                    icon: const Icon(Icons.tune, size: 18),
                    tooltip: 'Nombre requis',
                    onPressed: () => _modifierNombreRole(role),
                  ),
                if (_peutModifier)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _supprimerRole(role),
                  ),
              ],
            ),
            Text('Grades: ${_gradesTexte(role.gradesAutorises)}',
                style: Theme.of(context).textTheme.bodySmall),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: role.affectations
                  .map((a) => Chip(
                        label: Text(a.nomAffichage, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onDeleted: _peutModifier ? () => _retirer(a) : null,
                      ))
                  .toList(),
            ),
            if (_peutModifier)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _affecterRole(role),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Affecter'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _carteQrf(ServiceQrf qrf) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      '${qrf.titre}  (${qrf.membres.length}/${qrf.effectifRequis})',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (qrf.estEquipage)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Chip(
                      label: Text(
                          '${qrf.enginInfo?.libelle ?? qrf.engin ?? ''}'
                          '${qrf.nombreEquipages > 1 ? ' x${qrf.nombreEquipages}' : ''}',
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (_peutModifier && !qrf.estEquipage)
                  IconButton(
                    icon: const Icon(Icons.person_add_alt, size: 18),
                    tooltip: 'Ajouter un équipier',
                    onPressed: () => _ajouterMembreQrf(qrf),
                  ),
                if (_peutModifier && qrf.estEquipage)
                  IconButton(
                    icon: const Icon(Icons.military_tech, size: 18),
                    tooltip: 'Grades par poste',
                    onPressed: () => _editerGradesQrf(qrf),
                  ),
                if (_peutModifier)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _supprimerQrf(qrf),
                  ),
              ],
            ),
            Text(qrf.sousTitre, style: Theme.of(context).textTheme.bodySmall),
            if (qrf.estEquipage && qrf.gradesFonctions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Grades — ${_resumeGradesFonction(qrf)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            if (!qrf.complet)
              Text('Effectif incomplet',
                  style:
                      TextStyle(color: Colors.orange.shade800, fontSize: 12)),
            if (qrf.estEquipage && qrf.nombreEquipages > 1)
              ..._blocsEquipages(qrf)
            else
              _chipsMembres(qrf.membres),
            if (_peutModifier && qrf.estEquipage && !qrf.complet)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _remplirEquipage(qrf),
                  icon: const Icon(Icons.group_add, size: 18),
                  label: const Text('Compléter l\'équipage'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chipsMembres(List<ServiceQrfMembre> membres) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: membres
          .map((m) => Chip(
                label: Text('${m.fonctionLibelle}: ${m.nomAffichage}',
                    style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                onDeleted: _peutModifier ? () => _retirerMembreQrf(m) : null,
              ))
          .toList(),
    );
  }

  /// Un sous-bloc par equipage (QRF regroupant plusieurs equipages).
  List<Widget> _blocsEquipages(ServiceQrf qrf) {
    final widgets = <Widget>[];
    for (var e = 1; e <= qrf.nombreEquipages; e++) {
      final membres = qrf.membresEquipage(e);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Row(
            children: [
              Text('Équipage $e',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 6),
              Text('(${membres.length}/${qrf.effectifEquipage})',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
      widgets.add(membres.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('Aucun membre', style: TextStyle(fontSize: 12)),
            )
          : _chipsMembres(membres));
    }
    return widgets;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  AppUser? get _acteur => context.read<AuthProvider>().user;

  Future<void> _creerPostePrincipal() async {
    final libelle = await _demanderLibelle('Nouveau poste principal');
    if (libelle == null) return;
    await context.read<ServiceProvider>().creerPostePrincipal(_serviceId, libelle, acteur: _acteur);
    await _rafraichirEtConfirmer();
  }

  Future<void> _creerPosteBasique(ServicePoste parent) async {
    final libelle = TextEditingController();
    final effectif = TextEditingController(text: '1');
    final debut = TextEditingController();
    final fin = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau poste basique'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: libelle, autofocus: true, decoration: const InputDecoration(labelText: 'Libellé du poste')),
              TextField(controller: effectif, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Effectif requis')),
              Row(children: [
                Expanded(child: TextField(controller: debut, decoration: const InputDecoration(labelText: 'Début (HH:MM)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: fin, decoration: const InputDecoration(labelText: 'Fin (HH:MM)'))),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (libelle.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await context.read<ServiceProvider>().creerPosteBasique(
            serviceId: _serviceId,
            parentId: parent.id!,
            libelle: libelle.text.trim(),
            effectifRequis: int.tryParse(effectif.text.trim()),
            debut: _vide(debut.text),
            fin: _vide(fin.text),
            acteur: _acteur,
          );
      await _rafraichirEtConfirmer();
    }
    libelle.dispose();
    effectif.dispose();
    debut.dispose();
    fin.dispose();
  }

  Future<void> _creerRole() async {
    final libelle = TextEditingController();
    final nombre = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau rôle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: libelle, autofocus: true, decoration: const InputDecoration(labelText: 'Libellé du rôle')),
            TextField(controller: nombre, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nombre requis')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (libelle.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await context.read<ServiceProvider>().creerRole(
            ServiceRole(
              serviceId: _serviceId,
              code: 'CUSTOM',
              libelle: libelle.text.trim(),
              nombreRequis: int.tryParse(nombre.text.trim()) ?? 1,
              ordre: _roles.length,
            ),
            acteur: _acteur,
          );
      await _rafraichirEtConfirmer();
    }
    libelle.dispose();
    nombre.dispose();
  }

  Future<void> _modifierNombreRole(ServiceRole role) async {
    final nombre = TextEditingController(text: '${role.nombreRequis}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(role.libelle),
        content: TextField(
          controller: nombre,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nombre requis'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Valider')),
        ],
      ),
    );
    if (ok == true) {
      await context.read<ServiceProvider>().modifierRoleNombre(role.id!, int.tryParse(nombre.text.trim()) ?? role.nombreRequis);
      await _rafraichirEtConfirmer();
    }
    nombre.dispose();
  }

  Future<void> _affecterTitulaire(ServicePoste poste, String role) async {
    final choix = await _choisirMilitaires(
      titre: role == 'CHEF_POSTE' ? 'Chef de poste - ${poste.libelle}' : 'Adjoint - ${poste.libelle}',
      max: 1,
      exclus: _affectes,
      gradesAutorises: poste.gradesPour(
          role == 'CHEF_POSTE' ? CibleGrade.chef : CibleGrade.adjoint),
    );
    if (choix == null || choix.isEmpty) return;
    await context.read<ServiceProvider>().affecterPoste(
          serviceId: _serviceId,
          posteId: poste.id!,
          militaireId: choix.first.id,
          role: role,
          acteur: _acteur,
        );
    await _rafraichirEtConfirmer();
  }

  Future<void> _ajouterFaction(ServicePoste poste) async {
    final choix = await _choisirMilitaires(
      titre: 'Faction - ${poste.libelle}',
      exclus: _affectes,
      gradesAutorises: poste.gradesFaction,
    );
    if (choix == null) return;
    for (final m in choix) {
      await context.read<ServiceProvider>().affecterPoste(
            serviceId: _serviceId,
            posteId: poste.id!,
            militaireId: m.id,
            role: 'FACTION',
            acteur: _acteur,
          );
    }
    await _rafraichirEtConfirmer();
  }

  Future<void> _affecterRole(ServiceRole role) async {
    final choix = await _choisirMilitaires(
      titre: role.libelle,
      max: (role.nombreRequis - role.affectations.length).clamp(1, role.nombreRequis).toInt(),
      exclus: _affectes,
      gradesAutorises: role.gradesAutorises,
    );
    if (choix == null) return;
    for (final m in choix) {
      await context.read<ServiceProvider>().affecterRole(
            serviceId: _serviceId,
            roleId: role.id!,
            militaireId: m.id,
            acteur: _acteur,
          );
    }
    await _rafraichirEtConfirmer();
  }

  Future<void> _retirer(AffectationService a) async {
    if (a.id == null) return;
    await context.read<ServiceProvider>().retirerAffectation(a.id!);
    await _rafraichirEtConfirmer();
  }

  // ---------------------------------------------------------------------------
  // QRF
  // ---------------------------------------------------------------------------
  Future<void> _ajouterQrf() async {
    final type = await _choisirParmi('Type de QRF', kTypesQrf);
    if (type == null || !mounted) return;
    final mode = await _choisirParmi('Composition de la QRF', kModesQrf);
    if (mode == null || !mounted) return;
    final prov = context.read<ServiceProvider>();

    if (mode == ModeQrf.equipage) {
      // 1. Nombre d'equipages a composer (specifie en premier).
      final nombre = await _demanderNombre(
          'Nombre d\'équipages', 'Nombre d\'équipages à composer');
      if (nombre == null || !mounted) return;
      // 2. Type d'engin : definit les postes de l'equipage.
      final enginCode = await _choisirParmi('Type d\'engin blindé',
          {for (final e in kEnginsBlindes) e.code: e.libelle});
      if (enginCode == null || !mounted) return;
      final info = enginParCode(enginCode);
      if (info == null) return;
      // 3. Grades autorises par poste (fonction).
      final grades = await _demanderGradesFonction(info);
      if (grades == null || !mounted) return;
      // 4. Composition de chaque equipage (les cavaliers portes, 3 par
      //    equipage, sont selectionnes par cases a cocher). Les equipages sont
      //    regroupes dans une seule QRF (un seul bloc a l'affichage).
      final membres = <ServiceQrfMembre>[];
      final pris = <int>{..._affectes};
      for (var e = 1; e <= nombre; e++) {
        for (final g in groupesFonction(info.fonctions)) {
          final libelle = kFonctionEquipageLibelle[g.fonction] ?? g.fonction;
          final choix = await _choisirMilitaires(
            titre: '${info.libelle} - Équipage $e - $libelle'
                '${g.nombre > 1 ? ' (${g.nombre})' : ''}',
            max: g.nombre,
            exclus: pris,
            gradesAutorises: grades[g.fonction] ?? const <int>{},
          );
          if (choix == null || !mounted) return;
          for (final m in choix) {
            pris.add(m.id);
            membres.add(ServiceQrfMembre(
              fonction: g.fonction,
              militaireId: m.id,
              militaireNom: m.nom,
              gradeCode: m.gradeCode,
              equipage: e,
            ));
          }
        }
      }
      await prov.creerQrf(
        ServiceQrf(
          serviceId: _serviceId,
          type: type,
          mode: mode,
          engin: enginCode,
          effectif: info.effectif,
          nombreEquipages: nombre,
          ordre: _qrfs.length,
          membres: membres,
          gradesFonctions: grades,
        ),
        acteur: _acteur,
      );
      await _rafraichirEtConfirmer(nombre > 1
          ? 'QRF créée ($nombre équipages).'
          : 'QRF créée.');
      return;
    }

    final effectif = await _demanderNombre(
        'Effectif de la QRF', 'Nombre de militaires (liste)');
    if (effectif == null || effectif <= 0 || !mounted) return;
    final choix = await _choisirMilitaires(
      titre: 'QRF - sélection des équipiers',
      max: effectif,
      exclus: _affectes,
    );
    if (choix == null || !mounted) return;
    await prov.creerQrf(
      ServiceQrf(
        serviceId: _serviceId,
        type: type,
        mode: mode,
        effectif: effectif,
        ordre: _qrfs.length,
        membres: choix
            .map((m) => ServiceQrfMembre(
                  fonction: FonctionEquipage.equipier,
                  militaireId: m.id,
                  militaireNom: m.nom,
                  gradeCode: m.gradeCode,
                ))
            .toList(),
      ),
      acteur: _acteur,
    );
    await _rafraichirEtConfirmer('QRF créée.');
  }

  Future<void> _ajouterMembreQrf(ServiceQrf qrf) async {
    final reste = qrf.effectifRequis - qrf.membres.length;
    if (reste <= 0) return;
    final choix = await _choisirMilitaires(
      titre: qrf.titre,
      max: reste,
      exclus: _affectes,
    );
    if (choix == null || choix.isEmpty) return;
    final prov = context.read<ServiceProvider>();
    for (final m in choix) {
      await prov.ajouterMembreQrf(
        qrfId: qrf.id!,
        fonction: FonctionEquipage.equipier,
        militaireId: m.id,
        acteur: _acteur,
      );
    }
    await _rafraichirEtConfirmer('QRF mise à jour.');
  }

  Future<void> _remplirEquipage(ServiceQrf qrf) async {
    final info = qrf.enginInfo;
    if (info == null) return;
    final prov = context.read<ServiceProvider>();
    final pris = <int>{..._affectes};
    for (final m in qrf.membres) {
      if (m.militaireId != null) pris.add(m.militaireId!);
    }
    final nbEquipages = qrf.nombreEquipages < 1 ? 1 : qrf.nombreEquipages;
    final multi = nbEquipages > 1;
    for (var e = 1; e <= nbEquipages; e++) {
      final equipage = qrf.membresEquipage(e);
      for (final g in groupesFonction(info.fonctions)) {
        final existants =
            equipage.where((m) => m.fonction == g.fonction).length;
        final manquants = g.nombre - existants;
        if (manquants <= 0) continue;
        final libelle = kFonctionEquipageLibelle[g.fonction] ?? g.fonction;
        final choix = await _choisirMilitaires(
          titre: '${info.libelle} - ${multi ? 'Équipage $e - ' : ''}'
              '$libelle ($manquants)',
          max: manquants,
          exclus: pris,
          gradesAutorises: qrf.gradesPourFonction(g.fonction),
        );
        if (choix == null || !mounted) return;
        for (final m in choix) {
          pris.add(m.id);
          await prov.ajouterMembreQrf(
            qrfId: qrf.id!,
            fonction: g.fonction,
            militaireId: m.id,
            equipage: e,
            acteur: _acteur,
          );
        }
      }
    }
    await _rafraichirEtConfirmer('Équipage complété.');
  }

  /// Configure les grades autorises pour chaque poste (fonction) d'un
  /// equipage. Retourne null si l'utilisateur annule.
  Future<Map<String, Set<int>>?> _demanderGradesFonction(
    EnginBlinde info, {
    Map<String, Set<int>>? actuels,
  }) async {
    final groupes = groupesFonction(info.fonctions);
    final selection = <String, Set<int>>{
      for (final g in groupes)
        g.fonction: {...(actuels?[g.fonction] ?? const <int>{})},
    };
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Grades par poste - ${info.libelle}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                      'Définissez les grades autorisés pour chaque poste de '
                      'l\'équipage. Par défaut : tous grades.',
                      style: TextStyle(fontSize: 12)),
                ),
                for (final g in groupes)
                  Builder(builder: (ctx) {
                    final libelle =
                        kFonctionEquipageLibelle[g.fonction] ?? g.fonction;
                    final grades = selection[g.fonction] ?? const <int>{};
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '$libelle${g.nombre > 1 ? '  (x${g.nombre})' : ''}'),
                      subtitle: Text(_gradesTexte(grades)),
                      trailing: const Icon(Icons.tune, size: 18),
                      onTap: () async {
                        final res = await _configurerGrades(
                            'Grades - $libelle', grades);
                        if (res == null) return;
                        setSt(() => selection[g.fonction] = res);
                      },
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Valider')),
          ],
        ),
      ),
    );
    if (res != true) return null;
    return selection;
  }

  /// Modifie les grades autorises par poste d'un equipage existant.
  Future<void> _editerGradesQrf(ServiceQrf qrf) async {
    final info = qrf.enginInfo;
    if (info == null) return;
    final grades =
        await _demanderGradesFonction(info, actuels: qrf.gradesFonctions);
    if (grades == null || !mounted) return;
    await context
        .read<ServiceProvider>()
        .definirGradesQrf(qrf.id!, grades, acteur: _acteur);
    await _rafraichirEtConfirmer('Grades de la QRF mis à jour.');
  }

  Future<void> _retirerMembreQrf(ServiceQrfMembre m) async {
    if (m.id == null) return;
    await context.read<ServiceProvider>().retirerMembreQrf(m.id!);
    await _rafraichirEtConfirmer('QRF mise à jour.');
  }

  Future<void> _supprimerQrf(ServiceQrf qrf) async {
    final ok = await _confirmer('Supprimer ${qrf.titre} ?');
    if (!ok) return;
    await context.read<ServiceProvider>().supprimerQrf(qrf.id!, acteur: _acteur);
    await _rafraichirEtConfirmer('QRF supprimée.');
  }

  Future<void> _supprimerPoste(ServicePoste poste) async {
    final ok = await _confirmer('Supprimer « ${poste.libelle} » ?');
    if (!ok) return;
    await context.read<ServiceProvider>().supprimerPoste(poste.id!, acteur: _acteur);
    await _rafraichirEtConfirmer();
  }

  Future<void> _supprimerRole(ServiceRole role) async {
    final ok = await _confirmer('Supprimer le rôle « ${role.libelle} » ?');
    if (!ok) return;
    await context.read<ServiceProvider>().supprimerRole(role.id!, acteur: _acteur);
    await _rafraichirEtConfirmer();
  }

  Future<bool> _confirmer(String message) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    return res ?? false;
  }

  Future<String?> _demanderLibelle(String titre) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Libellé')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }

  Future<String?> _choisirParmi(String titre, Map<String, String> options) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(titre)),
            for (final e in options.entries)
              ListTile(
                title: Text(e.value),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
          ],
        ),
      ),
    );
  }

  Future<int?> _demanderNombre(String titre, String label) async {
    final ctrl = TextEditingController();
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return res;
  }

  Future<List<MilitaireOption>?> _choisirMilitaires({
    required String titre,
    int? max,
    Set<int> exclus = const {},
    Set<int> gradesAutorises = const {},
  }) async {
    final dispo = _militaires
        .where((m) =>
            !exclus.contains(m.id) &&
            (gradesAutorises.isEmpty ||
                (m.gradeId != null && gradesAutorises.contains(m.gradeId))))
        .toList();
    final selection = <int>{};
    var filtre = '';
    return showModalBottomSheet<List<MilitaireOption>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final liste = dispo
                .where((m) => m.nomAffichage.toLowerCase().contains(filtre.toLowerCase()))
                .toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.95,
              builder: (ctx, controller) => Column(
                children: [
                  ListTile(title: Text(titre), dense: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un militaire...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setSt(() => filtre = v),
                    ),
                  ),
                  Expanded(
                    child: liste.isEmpty
                        ? const Center(child: Text('Aucun militaire.'))
                        : ListView.builder(
                            controller: controller,
                            itemCount: liste.length,
                            itemBuilder: (c, i) {
                              final m = liste[i];
                              return CheckboxListTile(
                                dense: true,
                                value: selection.contains(m.id),
                                title: Text(m.nomAffichage),
                                onChanged: (v) => setSt(() {
                                  if (v == true) {
                                    if (max != null && max > 0) {
                                      if (max == 1) {
                                        selection
                                          ..clear()
                                          ..add(m.id);
                                      } else if (selection.length < max) {
                                        selection.add(m.id);
                                      }
                                    } else {
                                      selection.add(m.id);
                                    }
                                  } else {
                                    selection.remove(m.id);
                                  }
                                }),
                              );
                            },
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: selection.isEmpty
                              ? null
                              : () => Navigator.pop(
                                    ctx,
                                    dispo.where((m) => selection.contains(m.id)).toList(),
                                  ),
                          child: Text('Valider (${selection.length})'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _gradeCode(int id) =>
      context.read<ReferentielProvider>().gradeParId(id)?.code ?? '$id';

  String _gradesTexte(Set<int> ids) {
    if (ids.isEmpty) return 'Tous grades';
    final codes = ids.map(_gradeCode).toList()..sort();
    return codes.join(', ');
  }

  /// Resume lisible des grades definis par poste pour un equipage.
  String _resumeGradesFonction(ServiceQrf qrf) {
    final info = qrf.enginInfo;
    if (info == null) return '';
    return groupesFonction(info.fonctions)
        .where((g) => qrf.gradesPourFonction(g.fonction).isNotEmpty)
        .map((g) =>
            '${kFonctionEquipageLibelle[g.fonction] ?? g.fonction} : '
            '${_gradesTexte(qrf.gradesPourFonction(g.fonction))}')
        .join('  ·  ');
  }

  /// Regroupe les grades par categorie statutaire, dans l'ordre de [ordre]
  /// (categories du referentiel), les codes inconnus etant places en dernier.
  Map<String, List<RefItem>> _grouperParCategorie(
      List<RefItem> grades, List<String> ordre) {
    final groupes = <String, List<RefItem>>{};
    for (final g in grades) {
      (groupes[g.categorieCode ?? ''] ??= []).add(g);
    }
    final ordonne = <String, List<RefItem>>{};
    for (final code in ordre) {
      final items = groupes.remove(code);
      if (items != null) ordonne[code] = items;
    }
    ordonne.addAll(groupes);
    return ordonne;
  }

  Future<Set<int>?> _configurerGrades(String titre, Set<int> actuels) async {
    final selection = <int>{...actuels};
    final ref = context.read<ReferentielProvider>();
    final grades = ref.grades;
    final libelleCategorie = {for (final c in ref.categories) c.code: c.libelle};
    final groupes = _grouperParCategorie(
        grades, ref.categories.map((c) => c.code).toList());
    return showDialog<Set<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(titre),
          content: SizedBox(
            width: double.maxFinite,
            child: grades.isEmpty
                ? const Text('Aucun grade au référentiel.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final entree in groupes.entries) ...[
                        Builder(builder: (ctx) {
                          final ids = entree.value.map((g) => g.id).toSet();
                          final tous = selection.containsAll(ids);
                          final certains = selection.any(ids.contains);
                          return CheckboxListTile(
                            dense: true,
                            tristate: true,
                            value: tous ? true : (certains ? null : false),
                            title: Text(
                                (libelleCategorie[entree.key] ?? entree.key)
                                    .toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            onChanged: (_) => setSt(() {
                              if (tous) {
                                selection.removeAll(ids);
                              } else {
                                selection.addAll(ids);
                              }
                            }),
                          );
                        }),
                        for (final g in entree.value)
                          CheckboxListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.only(left: 32, right: 16),
                            value: selection.contains(g.id),
                            title: Text(g.code),
                            onChanged: (v) => setSt(() {
                              if (v == true) {
                                selection.add(g.id);
                              } else {
                                selection.remove(g.id);
                              }
                            }),
                          ),
                      ],
                    ],
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, <int>{}),
                child: const Text('Tous grades')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, selection),
                child: const Text('Valider')),
          ],
        ),
      ),
    );
  }

  Future<void> _editerGradesPoste(
      ServicePoste poste, String cible, String libelle) async {
    final res =
        await _configurerGrades('Grades - $libelle', poste.gradesPour(cible));
    if (res == null) return;
    await context.read<ServiceProvider>().definirGradesPoste(
          serviceId: _serviceId,
          posteId: poste.id!,
          cible: cible,
          gradeIds: res,
          acteur: _acteur,
        );
    await _rafraichirEtConfirmer();
  }

  Future<void> _editerGradesRole(ServiceRole role) async {
    final res =
        await _configurerGrades('Grades - ${role.libelle}', role.gradesAutorises);
    if (res == null) return;
    await context.read<ServiceProvider>().definirGradesRole(
          serviceId: _serviceId,
          roleId: role.id!,
          gradeIds: res,
          acteur: _acteur,
        );
    await _rafraichirEtConfirmer();
  }

  static String? _vide(String s) {
    final v = s.trim();
    return v.isEmpty ? null : v;
  }
}
