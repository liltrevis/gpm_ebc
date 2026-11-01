import 'package:flutter/foundation.dart';

import '../data/service_repository.dart';
import '../models/app_user.dart';
import '../models/service.dart';

/// Etat des services (gardes, patrouilles, quarts...).
class ServiceProvider extends ChangeNotifier {
  final ServiceRepository _repo;
  ServiceProvider(this._repo);

  List<ServiceModel> liste = [];
  bool loading = false;
  String? dateFiltre;
  int? perimetreSectionId;
  int? perimetreCreateurId;

  /// Applique (ou retire) le perimetre du compte connecte puis recharge.
  void definirPerimetre({int? sectionId, int? createurId}) {
    perimetreSectionId = sectionId;
    perimetreCreateurId = createurId;
    charger();
  }

  /// Precision de position derivee du service d'astreinte ("En service" /
  /// "De faction") par militaire, pour le moment courant.
  Map<int, String> positionsService = {};

  Future<void> charger() async {
    loading = true;
    notifyListeners();
    try {
      liste = await _repo.lister(
        date: dateFiltre,
        sectionId: perimetreSectionId,
        createdBy: perimetreCreateurId,
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Recalcule les positions derivees des services (En service / De faction).
  Future<void> chargerPositions() async {
    positionsService =
        await _repo.positionsService(sectionId: perimetreSectionId);
    notifyListeners();
  }

  /// Precision de position d'un militaire ("En service" / "De faction") ou null.
  String? positionService(int? militaireId) =>
      militaireId == null ? null : positionsService[militaireId];

  /// Positions derivees restreintes a un peloton (detail du tableau de bord).
  Future<Map<int, String>> positionsServiceDe(int sectionId) =>
      _repo.positionsService(sectionId: sectionId);

  Future<ServiceModel?> detail(int id) => _repo.parId(id);

  Future<List<AffectationService>> proposerEquitable({
    required String date,
    required int effectif,
  }) =>
      _repo.selectionEquitable(
          date: date, effectif: effectif, sectionId: perimetreSectionId);

  /// Cree un service et retourne son enregistrement (avec son id) ou null.
  Future<ServiceModel?> creer(
    ServiceModel service,
    List<AffectationService> affectations, {
    AppUser? acteur,
  }) async {
    final id = await _repo.creer(service,
        affectations: affectations,
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet);
    await charger();
    return _repo.parId(id);
  }

  Future<void> valider(int id, {AppUser? acteur}) async {
    await _repo.valider(id, utilisateurId: acteur?.id, utilisateurNom: acteur?.nomComplet);
    await charger();
  }

  /// Modifie un service existant.
  Future<void> modifierService(ServiceModel service, {AppUser? acteur}) async {
    await _repo.modifier(service,
        utilisateurId: acteur?.id, utilisateurNom: acteur?.nomComplet);
    await charger();
  }

  /// Supprime un service et ses donnees rattachees.
  Future<void> supprimerService(int id, {AppUser? acteur}) async {
    await _repo.supprimer(id,
        utilisateurId: acteur?.id, utilisateurNom: acteur?.nomComplet);
    await charger();
  }

  Future<void> marquerPresence(int affectationId, bool present) =>
      _repo.marquerPresence(affectationId, present);

  // ---------------------------------------------------------------------------
  // Postes et roles d'un service.
  // ---------------------------------------------------------------------------
  Future<List<ServicePoste>> postes(int serviceId) => _repo.postes(serviceId);

  Future<List<ServiceRole>> roles(int serviceId) => _repo.roles(serviceId);

  Future<void> assurerRolesParDefaut(int serviceId) =>
      _repo.assurerRolesParDefaut(serviceId);

  Future<List<MilitaireOption>> militaires() =>
      _repo.militaires(sectionId: perimetreSectionId);

  Future<void> creerPostePrincipal(
    int serviceId,
    String libelle, {
    AppUser? acteur,
  }) =>
      _repo.creerPoste(
        ServicePoste(
          serviceId: serviceId,
          libelle: libelle,
          type: TypePoste.principal,
        ),
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet,
      );

  Future<void> creerPosteBasique({
    required int serviceId,
    required int parentId,
    required String libelle,
    int? effectifRequis,
    String? debut,
    String? fin,
    AppUser? acteur,
  }) =>
      _repo.creerPoste(
        ServicePoste(
          serviceId: serviceId,
          parentId: parentId,
          libelle: libelle,
          type: TypePoste.basique,
          effectifRequis: effectifRequis,
          creneauDebut: debut,
          creneauFin: fin,
        ),
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet,
      );

  Future<void> supprimerPoste(int id, {AppUser? acteur}) => _repo.supprimerPoste(
        id,
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet,
      );

  Future<void> affecterPoste({
    required int serviceId,
    required int posteId,
    required int militaireId,
    required String role,
    AppUser? acteur,
  }) =>
      _repo.affecterPoste(
        serviceId: serviceId,
        posteId: posteId,
        militaireId: militaireId,
        role: role,
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet,
      );

  Future<void> retirerAffectation(int affectationId) =>
      _repo.retirerAffectation(affectationId);

  // ---------------------------------------------------------------------------
  // QRF (Piquet / Intervention) : en liste ou par equipage d'engin blinde.
  // ---------------------------------------------------------------------------
  Future<List<ServiceQrf>> qrfs(int serviceId) => _repo.qrfs(serviceId);

  Future<void> creerQrf(ServiceQrf qrf, {AppUser? acteur}) async {
    await _repo.creerQrf(qrf,
        utilisateurId: acteur?.id, utilisateurNom: acteur?.nomComplet);
  }

  Future<void> supprimerQrf(int qrfId, {AppUser? acteur}) =>
      _repo.supprimerQrf(qrfId,
          utilisateurId: acteur?.id, utilisateurNom: acteur?.nomComplet);

  Future<void> ajouterMembreQrf({
    required int qrfId,
    required String fonction,
    required int militaireId,
    int equipage = 1,
    AppUser? acteur,
  }) =>
      _repo.ajouterMembreQrf(
        qrfId: qrfId,
        fonction: fonction,
        militaireId: militaireId,
        equipage: equipage,
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet,
      );

  Future<void> retirerMembreQrf(int membreId) =>
      _repo.retirerMembreQrf(membreId);

  /// Definit les grades autorises par poste (fonction) d'un equipage QRF.
  Future<void> definirGradesQrf(
    int qrfId,
    Map<String, Set<int>> grades, {
    AppUser? acteur,
  }) =>
      _repo.definirGradesQrf(qrfId, grades,
          utilisateurId: acteur?.id, utilisateurNom: acteur?.nomComplet);

  Future<void> creerRole(
    ServiceRole role, {
    AppUser? acteur,
  }) =>
      _repo.creerRole(role,
          utilisateurId: acteur?.id, utilisateurNom: acteur?.nomComplet);

  Future<void> modifierRoleNombre(int roleId, int nombreRequis) =>
      _repo.modifierRoleNombre(roleId, nombreRequis);

  Future<void> supprimerRole(int roleId, {AppUser? acteur}) => _repo.supprimerRole(
        roleId,
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet,
      );

  Future<void> affecterRole({
    required int serviceId,
    required int roleId,
    required int militaireId,
    AppUser? acteur,
  }) =>
      _repo.affecterRole(
        serviceId: serviceId,
        roleId: roleId,
        militaireId: militaireId,
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet,
      );

  /// Definit les grades autorises pour une responsabilite d'un poste
  /// ([CibleGrade.chef], [CibleGrade.adjoint] ou [CibleGrade.faction]).
  Future<void> definirGradesPoste({
    required int serviceId,
    required int posteId,
    required String cible,
    required Set<int> gradeIds,
    AppUser? acteur,
  }) =>
      _repo.definirGrades(
        serviceId: serviceId,
        cibleType: cible,
        cibleId: posteId,
        gradeIds: gradeIds,
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet,
      );

  /// Definit les grades autorises pour un role d'astreinte.
  Future<void> definirGradesRole({
    required int serviceId,
    required int roleId,
    required Set<int> gradeIds,
    AppUser? acteur,
  }) =>
      _repo.definirGrades(
        serviceId: serviceId,
        cibleType: CibleGrade.role,
        cibleId: roleId,
        gradeIds: gradeIds,
        utilisateurId: acteur?.id,
        utilisateurNom: acteur?.nomComplet,
      );
}
