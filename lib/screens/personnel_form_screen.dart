import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/personnel.dart';
import '../models/referentiel.dart';
import '../providers/auth_provider.dart';
import '../providers/personnel_provider.dart';
import '../providers/referentiel_provider.dart';

/// Formulaire de creation / modification des donnees d'un militaire.
class PersonnelFormScreen extends StatefulWidget {
  final Personnel? personnel;
  const PersonnelFormScreen({super.key, this.personnel});

  @override
  State<PersonnelFormScreen> createState() => _PersonnelFormScreenState();
}

class _PersonnelFormScreenState extends State<PersonnelFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final Map<String, TextEditingController> _c = {
    'nom': TextEditingController(),
    'matricule': TextEditingController(),
    'mecano': TextEditingController(),
    'lieuNaissance': TextEditingController(),
    'nomPere': TextEditingController(),
    'nomMere': TextEditingController(),
    'nomConjoint': TextEditingController(),
    'nombreEnfants': TextEditingController(),
    'telephone': TextEditingController(),
    'personneAppeler': TextEditingController(),
    'lieuHabitation': TextEditingController(),
    'niveauEtude': TextEditingController(),
    'diplomeCivil': TextEditingController(),
    'diplomeMilitaire': TextEditingController(),
    'promotionClasse': TextEditingController(),
    'numeroCim': TextEditingController(),
    'cni': TextEditingController(),
    'nni': TextEditingController(),
    'passeport': TextEditingController(),
    'mugfci': TextEditingController(),
    'fpm': TextEditingController(),
    'cmu': TextEditingController(),
    'livretMatricule': TextEditingController(),
    'dossierPension': TextEditingController(),
    'droitDossierPension': TextEditingController(),
    'situationDossier': TextEditingController(),
    'taille': TextEditingController(),
    'uniteProvenance': TextEditingController(),
    'position': TextEditingController(),
  };

  int? _gradeId;
  int? _categorieId;
  int? _situationMatrimonialeId;
  int? _domaineId;
  int? _groupeSanguinId;
  int? _sectionId;
  int? _fonctionId;
  int? _statutId;
  String? _genre;
  String? _dateNaissance;
  String? _dateDebutService;
  String? _dateArriveeCorps;

  bool get _edition => widget.personnel != null;

  @override
  void initState() {
    super.initState();
    final p = widget.personnel;
    if (p == null) return;
    _gradeId = p.gradeId;
    _categorieId = p.categorieId;
    _situationMatrimonialeId = p.situationMatrimonialeId;
    _domaineId = p.domaineId;
    _groupeSanguinId = p.groupeSanguinId;
    _sectionId = p.sectionId;
    _fonctionId = p.fonctionId;
    _statutId = p.statutId;
    _genre = p.genre;
    _dateNaissance = p.dateNaissance;
    _dateDebutService = p.dateDebutService;
    _dateArriveeCorps = p.dateArriveeCorps;

    _txt('nom', p.nomPrenoms);
    _txt('matricule', p.matricule);
    _txt('mecano', p.mecano);
    _txt('lieuNaissance', p.lieuNaissance);
    _txt('nomPere', p.nomPere);
    _txt('nomMere', p.nomMere);
    _txt('nomConjoint', p.nomConjoint);
    _txt('nombreEnfants', p.nombreEnfants?.toString());
    _txt('telephone', p.telephone);
    _txt('personneAppeler', p.personneAppeler);
    _txt('lieuHabitation', p.lieuHabitation);
    _txt('niveauEtude', p.niveauEtude);
    _txt('diplomeCivil', p.diplomeCivil);
    _txt('diplomeMilitaire', p.diplomeMilitaire);
    _txt('promotionClasse', p.promotionClasse);
    _txt('numeroCim', p.numeroCim);
    _txt('cni', p.cni);
    _txt('nni', p.nni);
    _txt('passeport', p.passeport);
    _txt('mugfci', p.mugfci);
    _txt('fpm', p.fpm);
    _txt('cmu', p.cmu);
    _txt('livretMatricule', p.livretMatricule);
    _txt('dossierPension', p.dossierPension);
    _txt('droitDossierPension', p.droitDossierPension);
    _txt('situationDossier', p.situationDossier);
    _txt('taille', p.taille?.toString());
    _txt('uniteProvenance', p.uniteProvenance);
    _txt('position', p.position);
  }

  void _txt(String cle, String? valeur) {
    if (valeur != null && valeur.isNotEmpty) _c[cle]!.text = valeur;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(String cle) => _c[cle]!.text.trim();
  String? _nv(String cle) => _v(cle).isEmpty ? null : _v(cle);

  @override
  Widget build(BuildContext context) {
    final ref = context.watch<ReferentielProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(_edition ? 'Modifier le militaire' : 'Nouveau militaire')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _titre('Identite'),
            _champ(_c['nom']!, 'Nom et prenoms *'),
            _champ(_c['matricule']!, 'Matricule'),
            _champ(_c['mecano']!, 'Mecano'),
            _droppar<int?>('Grade', _gradeId, ref.grades,
                (v) => setState(() => _gradeId = v)),
            _droppar<int?>('Categorie', _categorieId, ref.categories,
                (v) => setState(() => _categorieId = v)),
            _dropdownSimple<String?>('Genre', _genre, const ['M', 'F'],
                (v) => setState(() => _genre = v)),
            _champDate('Date de naissance', _dateNaissance,
                (v) => setState(() => _dateNaissance = v)),
            _champ(_c['lieuNaissance']!, 'Lieu de naissance'),
            _champ(_c['nomPere']!, 'Nom du pere'),
            _champ(_c['nomMere']!, 'Nom de la mere'),

            _titre('Situation familiale'),
            _droppar<int?>('Situation matrimoniale', _situationMatrimonialeId,
                ref.situationsMatrimoniales,
                (v) => setState(() => _situationMatrimonialeId = v)),
            _champ(_c['nomConjoint']!, 'Nom du conjoint'),
            _champ(_c['nombreEnfants']!, 'Nombre d\'enfants',
                clavier: TextInputType.number),

            _titre('Contact et residence'),
            _champ(_c['telephone']!, 'Telephone', clavier: TextInputType.phone),
            _champ(_c['personneAppeler']!, 'Personne a appeler'),
            _champ(_c['lieuHabitation']!, 'Lieu d\'habitation'),

            _titre('Formation'),
            _champ(_c['niveauEtude']!, 'Niveau d\'etude'),
            _champ(_c['diplomeCivil']!, 'Diplome civil'),
            _champ(_c['diplomeMilitaire']!, 'Diplome militaire'),
            _champ(_c['promotionClasse']!, 'Promotion / classe'),
            _droppar<int?>('Domaine', _domaineId, ref.domaines,
                (v) => setState(() => _domaineId = v)),
            _champDate('Date debut service', _dateDebutService,
                (v) => setState(() => _dateDebutService = v)),

            _titre('Documents administratifs'),
            _champ(_c['numeroCim']!, 'Numero CIM'),
            _champ(_c['cni']!, 'CNI'),
            _champ(_c['nni']!, 'NNI'),
            _champ(_c['passeport']!, 'Passeport'),
            _champ(_c['mugfci']!, 'MUGEFCI'),
            _champ(_c['fpm']!, 'FPM'),
            _champ(_c['cmu']!, 'CMU'),
            _champ(_c['livretMatricule']!, 'Livret matricule'),
            _champ(_c['dossierPension']!, 'Dossier de pension'),
            _champ(_c['droitDossierPension']!, 'Droit a dossier de pension'),
            _champ(_c['situationDossier']!, 'Situation du dossier'),

            _titre('Medical'),
            _droppar<int?>('Groupe sanguin', _groupeSanguinId, ref.groupesSanguins,
                (v) => setState(() => _groupeSanguinId = v)),
            _champ(_c['taille']!, 'Taille (m)', clavier: TextInputType.number),

            _titre('Affectation'),
            _droppar<int?>('Peloton', _sectionId, ref.sections,
                (v) => setState(() => _sectionId = v)),
            _droppar<int?>('Fonction', _fonctionId, ref.fonctions,
                (v) => setState(() => _fonctionId = v)),
            if (!_edition)
              _droppar<int?>(
                'Statut',
                _statutId,
                ref.statuts
                    .map((s) => RefItem(id: s.id, code: s.code, libelle: s.libelle))
                    .toList(),
                (v) => setState(() => _statutId = v),
              ),
            _champDate('Date d\'arrivee au corps', _dateArriveeCorps,
                (v) => setState(() => _dateArriveeCorps = v)),
            _champ(_c['uniteProvenance']!, 'Unite de provenance'),
            _champ(_c['position']!, 'Position'),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _enregistrer,
              icon: const Icon(Icons.save),
              label: Text(_edition ? 'Enregistrer les modifications' : 'Enregistrer'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _titre(String texte) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(texte,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _champ(TextEditingController controller, String label,
      {TextInputType clavier = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: clavier,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _champDate(String label, String? valeur, ValueChanged<String?> onPick) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () async {
          final initial = valeur != null ? DateTime.tryParse(valeur) : null;
          final choisi = await showDatePicker(
            context: context,
            initialDate: initial ?? DateTime(1990),
            firstDate: DateTime(1950),
            lastDate: DateTime(2100),
          );
          if (choisi != null) {
            final iso = '${choisi.year.toString().padLeft(4, '0')}-'
                '${choisi.month.toString().padLeft(2, '0')}-'
                '${choisi.day.toString().padLeft(2, '0')}';
            onPick(iso);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (valeur != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => onPick(null),
                  ),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
          child: Text(valeur == null ? '-' : formatDateFr(valeur)),
        ),
      ),
    );
  }

  Widget _droppar<T>(
    String label,
    T? valeur,
    List<RefItem> items,
    ValueChanged<T?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<Object?>(
        initialValue: valeur,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((e) => DropdownMenuItem<Object?>(
                  value: e.id,
                  child: Text(e.libelle.isEmpty ? e.code : e.libelle),
                ))
            .toList(),
        onChanged: (v) => onChanged(v as T?),
      ),
    );
  }

  Widget _dropdownSimple<T>(
    String label,
    T? valeur,
    List<T> valeurs,
    ValueChanged<T?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<T>(
        initialValue: valeur,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: valeurs
            .map((e) => DropdownMenuItem<T>(value: e, child: Text('$e')))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _enregistrer() async {
    final nom = _v('nom');
    if (nom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom et prenoms est obligatoire.')),
      );
      return;
    }
    final prov = context.read<PersonnelProvider>();
    final auth = context.read<AuthProvider>();
    final base = _edition
        ? Personnel.fromMap(widget.personnel!.toMap())
        : Personnel.nouveau();

    final p = Personnel(
      id: base.id,
      gradeId: _gradeId,
      nomPrenoms: nom,
      matricule: _nv('matricule'),
      mecano: _nv('mecano'),
      escadronId: base.escadronId,
      position: _nv('position') ?? base.position,
      positionPrecision: base.positionPrecision,
      positionDebut: base.positionDebut,
      positionDuree: base.positionDuree,
      dateNaissance: _dateNaissance,
      lieuNaissance: _nv('lieuNaissance'),
      nomPere: _nv('nomPere'),
      nomMere: _nv('nomMere'),
      categorieId: _categorieId,
      genre: _genre,
      situationMatrimonialeId: _situationMatrimonialeId,
      dateDebutService: _dateDebutService,
      dateNomination: base.dateNomination,
      referenceNomination: base.referenceNomination,
      dateArriveeCorps: _dateArriveeCorps,
      dateEffet: base.dateEffet,
      uniteProvenance: _nv('uniteProvenance'),
      referenceAffectation: base.referenceAffectation,
      dateAffectation: base.dateAffectation,
      nouvelleUniteAffectation: base.nouvelleUniteAffectation,
      reference: base.reference,
      domaineId: _domaineId,
      diplomeMilitaire: _nv('diplomeMilitaire'),
      decision: base.decision,
      diplomeCivil: _nv('diplomeCivil'),
      niveauEtude: _nv('niveauEtude'),
      nomConjoint: _nv('nomConjoint'),
      nombreEnfants: int.tryParse(_v('nombreEnfants')),
      personneAppeler: _nv('personneAppeler'),
      telephone: _nv('telephone'),
      numeroCim: _nv('numeroCim'),
      cni: _nv('cni'),
      nni: _nv('nni'),
      passeport: _nv('passeport'),
      mugfci: _nv('mugfci'),
      fpm: _nv('fpm'),
      cmu: _nv('cmu'),
      groupeSanguinId: _groupeSanguinId,
      lieuHabitation: _nv('lieuHabitation'),
      livretMatricule: _nv('livretMatricule'),
      dossierPension: _nv('dossierPension'),
      droitDossierPension: _nv('droitDossierPension'),
      situationDossier: _nv('situationDossier'),
      promotionClasse: _nv('promotionClasse'),
      taille: double.tryParse(_v('taille').replaceAll(',', '.')),
      actif: base.actif,
    );

    if (_edition) {
      await prov.modifier(p,
          sectionId: _sectionId, fonctionId: _fonctionId, acteur: auth.user);
    } else {
      await prov.creer(p,
          sectionId: _sectionId,
          fonctionId: _fonctionId,
          statutId: _statutId,
          acteur: auth.user);
    }
    if (mounted) Navigator.of(context).pop();
  }
}
