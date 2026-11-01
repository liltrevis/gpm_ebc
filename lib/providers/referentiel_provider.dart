import 'package:flutter/foundation.dart';

import '../data/referentiel_repository.dart';
import '../models/referentiel.dart';

/// Charge et expose les tables de reference.
class ReferentielProvider extends ChangeNotifier {
  final ReferentielRepository _repo;
  ReferentielProvider(this._repo);

  List<RefItem> grades = [];
  List<RefItem> categories = [];
  List<RefItem> escadrons = [];
  List<RefItem> sections = [];
  List<RefItem> fonctions = [];
  List<RefItem> typesService = [];
  List<RefItem> postes = [];
  List<RefItem> typesArme = [];
  List<RefItem> groupesSanguins = [];
  List<RefItem> situationsMatrimoniales = [];
  List<RefItem> domaines = [];
  List<StatutItem> statuts = [];

  bool charge = false;

  Future<void> charger() async {
    grades = await _repo.grades();
    categories = await _repo.categories();
    escadrons = await _repo.escadrons();
    sections = await _repo.sections();
    fonctions = await _repo.fonctions();
    typesService = await _repo.typesService();
    postes = await _repo.postes();
    typesArme = await _repo.typesArme();
    groupesSanguins = await _repo.groupesSanguins();
    situationsMatrimoniales = await _repo.situationsMatrimoniales();
    domaines = await _repo.domaines();
    statuts = await _repo.statuts();
    charge = true;
    notifyListeners();
  }

  RefItem? gradeParId(int? id) => _parId(grades, id);
  RefItem? sectionParId(int? id) => _parId(sections, id);
  RefItem? fonctionParId(int? id) => _parId(fonctions, id);
  RefItem? categorieParId(int? id) => _parId(categories, id);
  RefItem? groupeSanguinParId(int? id) => _parId(groupesSanguins, id);
  RefItem? situationMatrimonialeParId(int? id) => _parId(situationsMatrimoniales, id);
  RefItem? domaineParId(int? id) => _parId(domaines, id);
  StatutItem? statutParId(int? id) {
    if (id == null) return null;
    for (final s in statuts) {
      if (s.id == id) return s;
    }
    return null;
  }

  RefItem? _parId(List<RefItem> liste, int? id) {
    if (id == null) return null;
    for (final e in liste) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Precisions de position proposees (defauts + ajouts utilisateur).
  Future<List<String>> precisionsPosition(String position) async {
    final items = await _repo.precisionsPosition(position);
    return items.map((e) => e.libelle).toList();
  }

  /// Ajoute un element de referentiel (option "Autre a preciser") et recharge
  /// les listes. Retourne l'id cree (ou existant).
  Future<int> ajouterReferentiel(String tableRef, String libelle) async {
    const tables = <String, String>{
      'grades': 'grade',
      'categories': 'categorie',
      'escadrons': 'escadron',
      'sections': 'section',
      'fonctions': 'fonction',
      'groupesSanguins': 'groupe_sanguin',
      'situationsMatrimoniales': 'situation_matrimoniale',
      'domaines': 'domaine',
    };
    final table = tables[tableRef];
    if (table == null) return -1;
    final id = await _repo.ajouterItem(table,
        libelle: libelle,
        escadronId: tableRef == 'sections' && escadrons.isNotEmpty
            ? escadrons.first.id
            : null);
    await charger();
    return id;
  }

  /// Enregistre une nouvelle precision de position.
  Future<void> ajouterPrecisionPosition({
    required String position,
    required String libelle,
  }) =>
      _repo.ajouterPrecisionPosition(position: position, libelle: libelle);
}
