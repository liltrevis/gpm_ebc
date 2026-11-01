import 'package:flutter/foundation.dart';

import '../core/champs_personnel.dart';
import '../core/constants.dart';
import '../data/personnel_repository.dart';
import '../models/app_user.dart';
import '../models/personnel.dart';

/// Criteres de tri de la liste des effectifs (tri principal puis secondaire).
enum TriEffectif { peloton, categorie, grade, nom }

/// Etat de la liste des militaires et des operations associees.
class PersonnelProvider extends ChangeNotifier {
  final PersonnelRepository _repo;
  PersonnelProvider(this._repo);

  List<Personnel> liste = [];
  bool loading = false;
  String recherche = '';
  int? filtreSectionId;
  List<String>? filtreStatutCodes;
  bool? filtreDisponible;

  /// Criteres de tri appliques, du plus prioritaire au moins prioritaire.
  List<TriEffectif> trisEffectif = [];

  /// Peloton impose par le compte connecte (Chef de Peloton). Lorsqu'il est
  /// defini, il prime sur le filtre manuel de l'onglet Effectifs.
  int? perimetreSectionId;

  /// Applique (ou retire) le perimetre du compte et recharge la liste.
  void definirPerimetre(int? sectionId) {
    if (perimetreSectionId == sectionId) return;
    perimetreSectionId = sectionId;
    charger();
  }

  /// Code unique utilise par le menu deroulant de la liste (null si 0 ou
  /// plusieurs statuts filtres).
  String? get filtreStatutCode {
    final c = filtreStatutCodes;
    if (c == null || c.length != 1) return null;
    return c.first;
  }

  Future<void> charger() async {
    loading = true;
    notifyListeners();
    try {
      liste = await _repo.lister(
        recherche: recherche,
        sectionId: perimetreSectionId ?? filtreSectionId,
        statutCodes: filtreStatutCodes,
        disponible: filtreDisponible,
      );
      _appliquerTri();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Definit et applique les criteres de tri (1er puis 2e).
  void definirTris(List<TriEffectif> tris) {
    trisEffectif = List<TriEffectif>.from(tris);
    _appliquerTri();
    notifyListeners();
  }

  void _appliquerTri() {
    if (trisEffectif.isEmpty) return;
    liste.sort((a, b) {
      for (final t in trisEffectif) {
        final c = _comparer(t, a, b);
        if (c != 0) return c;
      }
      return 0;
    });
  }

  int _comparer(TriEffectif tri, Personnel a, Personnel b) {
    switch (tri) {
      case TriEffectif.peloton:
        return _texte(a.sectionLibelle).compareTo(_texte(b.sectionLibelle));
      case TriEffectif.categorie:
        return _ordreCategorie(a).compareTo(_ordreCategorie(b));
      case TriEffectif.grade:
        return _ordreGrade(a).compareTo(_ordreGrade(b));
      case TriEffectif.nom:
        return _texte(a.nomPrenoms).compareTo(_texte(b.nomPrenoms));
    }
  }

  static String _texte(String? valeur) => (valeur ?? '').toLowerCase().trim();

  static int _ordreCategorie(Personnel p) {
    const ordre = ['OFF', 'S-OFF', 'MDR'];
    final code = categorieDepuisGrade(p.gradeCode);
    final i = ordre.indexOf(code ?? 'MDR');
    return i < 0 ? ordre.length : i;
  }

  static int _ordreGrade(Personnel p) =>
      kGradeOrdre[(p.gradeCode ?? '').trim().toUpperCase()] ?? 999;

  void rechercher(String valeur) {
    recherche = valeur;
    charger();
  }

  void filtrerParSection(int? sectionId) {
    filtreSectionId = sectionId;
    charger();
  }

  void filtrerParStatut(String? statutCode) {
    filtreStatutCodes = statutCode == null ? null : [statutCode];
    filtreDisponible = null;
    charger();
  }

  /// Applique un filtre combine (utilise par le tableau de bord).
  void filtrerComplet({
    int? sectionId,
    List<String>? statutCodes,
    bool? disponible,
  }) {
    filtreSectionId = sectionId;
    filtreStatutCodes =
        (statutCodes == null || statutCodes.isEmpty) ? null : statutCodes;
    filtreDisponible = disponible;
    charger();
  }

  Future<Personnel?> detail(int id) => _repo.parId(id);

  /// Liste filtree sans modifier l'etat de l'onglet Effectifs.
  Future<List<Personnel>> parFiltre({
    int? sectionId,
    List<String>? statutCodes,
    bool? disponible,
  }) =>
      _repo.lister(
        sectionId: perimetreSectionId ?? sectionId,
        statutCodes: statutCodes,
        disponible: disponible,
        limite: 500,
      );

  Future<List<Personnel>> disponibles() => _repo.disponibles();

  Future<void> creer(
    Personnel p, {
    int? sectionId,
    int? fonctionId,
    int? statutId,
    AppUser? acteur,
  }) async {
    await _repo.creer(p,
        sectionId: sectionId,
        fonctionId: fonctionId,
        statutId: statutId,
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet);
    await charger();
  }

  Future<void> modifier(
    Personnel p, {
    int? sectionId,
    int? fonctionId,
    AppUser? acteur,
  }) async {
    await _repo.modifier(p,
        sectionId: sectionId,
        fonctionId: fonctionId,
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet);
    await charger();
  }

  Future<void> changerStatut({
    required int militaireId,
    required int statutId,
    String? motif,
    String? lieu,
    AppUser? acteur,
  }) async {
    await _repo.changerStatut(
      militaireId: militaireId,
      statutId: statutId,
      motif: motif,
      lieu: lieu,
      utilisateurId: acteur?.id,
      utilisateurNom: acteur?.nomComplet,
    );
    await charger();
  }

  Future<void> archiver(int id, {AppUser? acteur}) async {
    await _repo.archiver(id, utilisateurId: acteur?.id, utilisateurNom: acteur?.nomComplet);
    await charger();
  }

  /// Modifie la position d'un militaire et rafraichit aussitot les listes.
  Future<void> changerPosition({
    required int militaireId,
    required String? position,
    String? precision,
    String? debut,
    String? duree,
    AppUser? acteur,
  }) async {
    await _repo.changerPosition(
      militaireId: militaireId,
      position: position,
      precision: precision,
      debut: debut,
      duree: duree,
      utilisateurId: acteur?.id,
      utilisateurNom: acteur?.nomComplet,
    );
    await charger();
  }

  /// Applique une meme position (et precision, et duree) a plusieurs militaires
  /// en une seule fois (utilise par la validation d'une liste d'etat).
  Future<void> appliquerPositions({
    required List<int> militaireIds,
    required String? position,
    String? precision,
    String? duree,
    AppUser? acteur,
  }) async {
    for (final id in militaireIds) {
      await _repo.changerPosition(
        militaireId: id,
        position: position,
        precision: precision,
        duree: duree,
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet,
      );
    }
    await charger();
  }

  /// Met a jour une information (au choix) pour un groupe de militaires.
  Future<void> mettreAJourChampGroupe({
    required List<int> militaireIds,
    required ChampPersonnel champ,
    Object? valeur,
    String? positionPrecision,
    AppUser? acteur,
  }) async {
    switch (champ.type) {
      case TypeChamp.position:
        await appliquerPositions(
          militaireIds: militaireIds,
          position: valeur as String?,
          precision: positionPrecision,
          acteur: acteur,
        );
        return;
      case TypeChamp.section:
        await _repo.mettreAJourAffectation(
          ids: militaireIds,
          setSection: true,
          sectionId: valeur as int?,
          utilisateurId: acteur?.id,
          utilisateurNom: acteur?.nomComplet,
        );
        break;
      case TypeChamp.fonction:
        await _repo.mettreAJourAffectation(
          ids: militaireIds,
          setFonction: true,
          fonctionId: valeur as int?,
          utilisateurId: acteur?.id,
          utilisateurNom: acteur?.nomComplet,
        );
        break;
      default:
        await _repo.mettreAJourChamp(
          ids: militaireIds,
          colonne: champ.colonne!,
          valeur: valeur,
          utilisateurId: acteur?.id,
          utilisateurNom: acteur?.nomComplet,
        );
    }
    await charger();
  }
}
