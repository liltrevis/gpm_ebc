import 'dart:convert';

/// Un service (garde, patrouille, quart...) planifie ou effectue.
class ServiceModel {
  int? id;
  String date;
  String? creneauDebut;
  String? creneauFin;
  int? typeServiceId;
  String? typeLibelle;
  String? typeCode;
  /// Nom libre du service (renseigne pour le type "Autre service").
  String? libelle;
  int? posteId;
  String? posteLibelle;
  /// Duree du service en heures : 24 ou 48.
  int dureeHeures;
  /// Date de fin (yyyy-MM-dd) calculee a partir du debut + [dureeHeures].
  String? dateFin;
  String statut;
  String origine;
  List<AffectationService> affectations;

  ServiceModel({
    this.id,
    required this.date,
    this.creneauDebut,
    this.creneauFin,
    this.typeServiceId,
    this.typeLibelle,
    this.typeCode,
    this.libelle,
    this.posteId,
    this.posteLibelle,
    this.dureeHeures = 24,
    this.dateFin,
    this.statut = 'PLANIFIE',
    this.origine = 'MANUEL',
    List<AffectationService>? affectations,
  }) : affectations = affectations ?? [];

  factory ServiceModel.fromMap(Map<String, Object?> m) {
    return ServiceModel(
      id: m['id'] as int?,
      date: (m['date'] ?? '') as String,
      creneauDebut: m['creneau_debut'] as String?,
      creneauFin: m['creneau_fin'] as String?,
      typeServiceId: m['type_service_id'] as int?,
      typeLibelle: m['type_libelle'] as String?,
      typeCode: m['type_code'] as String?,
      libelle: m['libelle'] as String?,
      posteId: m['poste_id'] as int?,
      posteLibelle: m['poste_libelle'] as String?,
      dureeHeures: (m['duree_heures'] as int?) ?? 24,
      dateFin: m['date_fin'] as String?,
      statut: (m['statut'] ?? 'PLANIFIE') as String,
      origine: (m['origine'] ?? 'MANUEL') as String,
    );
  }

  /// Un service d'astreinte ouvre la gestion des postes et roles dedies.
  bool get estAstreinte => typeCode == 'ASTREINTE';

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'creneau_debut': creneauDebut,
        'creneau_fin': creneauFin,
        'duree_heures': dureeHeures,
        'date_fin': dateFin,
        'type_service_id': typeServiceId,
        'libelle': libelle,
        'poste_id': posteId,
        'statut': statut,
        'origine': origine,
      };

  bool get valide => statut == 'VALIDE';

  /// Nom affiche du service : le libelle libre s'il est renseigne, sinon le
  /// libelle du type.
  String get nom {
    final l = libelle?.trim();
    if (l != null && l.isNotEmpty) return l;
    return typeLibelle ?? 'Service';
  }

  /// Debut du service (date + creneau de debut) ou null si indetermine.
  DateTime? get debutDt {
    final jour = DateTime.tryParse(date);
    if (jour == null) return null;
    final parts = (creneauDebut ?? '').split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0].trim() : '');
    if (h == null) return null;
    final m = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
    return DateTime(jour.year, jour.month, jour.day, h, m);
  }
}

/// Creneau de faction de 2h : intervalle [debut, fin] tenu par un militaire.
class CreneauFaction {
  final DateTime debut;
  final DateTime fin;
  final AffectationService? affectation;
  const CreneauFaction(this.debut, this.fin, this.affectation);
}

/// Formate une heure au format HH:MM.
String hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Construit la boucle des creneaux de faction de 2h couvrant [dureeHeures]
/// a partir de [debut]. Les membres de [faction] tournent en round-robin :
/// chaque individu tient un creneau de 2h, puis le cycle reprend, jusqu'a la
/// fin globale de l'astreinte (dernier creneau partiel autorise).
List<CreneauFaction> creneauxFaction2h({
  required DateTime debut,
  required int dureeHeures,
  required List<AffectationService> faction,
}) {
  if (faction.isEmpty || dureeHeures <= 0) return const [];
  final finGlobale = debut.add(Duration(hours: dureeHeures));
  final creneaux = <CreneauFaction>[];
  var t = debut;
  var i = 0;
  while (t.isBefore(finGlobale)) {
    var fin = t.add(const Duration(hours: 2));
    if (fin.isAfter(finGlobale)) fin = finGlobale;
    creneaux.add(CreneauFaction(t, fin, faction[i % faction.length]));
    t = fin;
    i++;
  }
  return creneaux;
}

/// Affectation d'un militaire a un service.
class AffectationService {
  int? id;
  int? serviceId;
  int? militaireId;
  String? militaireNom;
  String? gradeCode;
  String? gradeLibelle;
  String roleService;
  bool present;
  String? observation;
  int? servicePosteId;
  int? serviceRoleId;

  AffectationService({
    this.id,
    this.serviceId,
    this.militaireId,
    this.militaireNom,
    this.gradeCode,
    this.gradeLibelle,
    this.roleService = 'SENTINELLE',
    this.present = true,
    this.observation,
    this.servicePosteId,
    this.serviceRoleId,
  });

  factory AffectationService.fromMap(Map<String, Object?> m) {
    return AffectationService(
      id: m['id'] as int?,
      serviceId: m['service_id'] as int?,
      militaireId: m['militaire_id'] as int?,
      militaireNom: m['militaire_nom'] as String?,
      gradeCode: m['grade_code'] as String?,
      gradeLibelle: m['grade_libelle'] as String?,
      roleService: (m['role_service'] ?? 'SENTINELLE') as String,
      present: ((m['present'] as int?) ?? 1) == 1,
      observation: m['observation'] as String?,
      servicePosteId: m['service_poste_id'] as int?,
      serviceRoleId: m['service_role_id'] as int?,
    );
  }

  /// Grade abrege (code du referentiel) prioritairement, sinon le libelle.
  String? get gradeAffiche => gradeCode ?? gradeLibelle;

  String get nomAffichage =>
      [gradeCode ?? gradeLibelle, militaireNom].whereType<String>().join(' ').trim();
}

/// Types de poste au sein d'un service.
class TypePoste {
  static const String principal = 'PRINCIPAL';
  static const String basique = 'BASIQUE';
}

/// Cibles de qualification : responsabilites d'un poste ou role dedie.
class CibleGrade {
  static const String chef = 'CHEF_POSTE';
  static const String adjoint = 'ADJOINT';
  static const String faction = 'FACTION';
  static const String role = 'ROLE';
}

/// Un poste d'un service : principal (avec chef, adjoint et postes basiques)
/// ou basique (garni par une faction).
class ServicePoste {
  int? id;
  int? serviceId;
  int? parentId;
  String libelle;
  String type;
  int? effectifRequis;
  String? creneauDebut;
  String? creneauFin;
  int ordre;
  String? observation;
  List<AffectationService> affectations;
  List<ServicePoste> enfants;

  /// Grades autorises par responsabilite : cles [CibleGrade.chef],
  /// [CibleGrade.adjoint] (poste principal) et [CibleGrade.faction] (basique).
  /// Un ensemble vide signifie "tous les grades".
  Map<String, Set<int>> gradesAutorises;

  ServicePoste({
    this.id,
    this.serviceId,
    this.parentId,
    required this.libelle,
    this.type = TypePoste.basique,
    this.effectifRequis,
    this.creneauDebut,
    this.creneauFin,
    this.ordre = 0,
    this.observation,
    List<AffectationService>? affectations,
    List<ServicePoste>? enfants,
    Map<String, Set<int>>? gradesAutorises,
  })  : affectations = affectations ?? [],
        enfants = enfants ?? [],
        gradesAutorises = gradesAutorises ?? {};

  factory ServicePoste.fromMap(Map<String, Object?> m) {
    return ServicePoste(
      id: m['id'] as int?,
      serviceId: m['service_id'] as int?,
      parentId: m['parent_id'] as int?,
      libelle: (m['libelle'] ?? '') as String,
      type: (m['type'] ?? TypePoste.basique) as String,
      effectifRequis: m['effectif_requis'] as int?,
      creneauDebut: m['creneau_debut'] as String?,
      creneauFin: m['creneau_fin'] as String?,
      ordre: (m['ordre'] as int?) ?? 0,
      observation: m['observation'] as String?,
    );
  }

  bool get estPrincipal => type == TypePoste.principal;

  Set<int> gradesPour(String cible) => gradesAutorises[cible] ?? const {};
  Set<int> get gradesChef => gradesPour(CibleGrade.chef);
  Set<int> get gradesAdjoint => gradesPour(CibleGrade.adjoint);
  Set<int> get gradesFaction => gradesPour(CibleGrade.faction);

  AffectationService? get chef => _parRole('CHEF_POSTE');
  AffectationService? get adjoint => _parRole('ADJOINT');

  AffectationService? _parRole(String role) {
    for (final a in affectations) {
      if (a.roleService == role) return a;
    }
    return null;
  }

  List<AffectationService> get faction =>
      affectations.where((a) => a.roleService == 'FACTION').toList();

  int get effectifFaction => faction.length;

  bool get complet =>
      effectifRequis == null || effectifFaction >= effectifRequis!;

  /// Construit l'arborescence (principaux + leurs postes basiques) a partir
  /// d'une liste plate renvoyee par la base.
  static List<ServicePoste> arborescence(List<ServicePoste> plats) {
    final principaux = plats.where((p) => p.parentId == null).toList()
      ..sort((a, b) => _comparer(a, b));
    for (final p in principaux) {
      p.enfants = plats.where((e) => e.parentId == p.id).toList()
        ..sort((a, b) => _comparer(a, b));
    }
    return principaux;
  }

  static int _comparer(ServicePoste a, ServicePoste b) {
    final c = a.ordre.compareTo(b.ordre);
    return c != 0 ? c : (a.id ?? 0).compareTo(b.id ?? 0);
  }
}

/// Un role propre a l'astreinte (officier de permanence, QRF...).
class ServiceRole {
  int? id;
  int? serviceId;
  String code;
  String libelle;
  int nombreRequis;
  int ordre;
  List<AffectationService> affectations;
  /// Grades autorises pour ce role (vide = tous les grades).
  Set<int> gradesAutorises;

  ServiceRole({
    this.id,
    this.serviceId,
    this.code = 'ROLE',
    required this.libelle,
    this.nombreRequis = 1,
    this.ordre = 0,
    List<AffectationService>? affectations,
    Set<int>? gradesAutorises,
  })  : affectations = affectations ?? [],
        gradesAutorises = gradesAutorises ?? {};

  factory ServiceRole.fromMap(Map<String, Object?> m) {
    return ServiceRole(
      id: m['id'] as int?,
      serviceId: m['service_id'] as int?,
      code: (m['code'] ?? 'ROLE') as String,
      libelle: (m['libelle'] ?? '') as String,
      nombreRequis: (m['nombre_requis'] as int?) ?? 1,
      ordre: (m['ordre'] as int?) ?? 0,
    );
  }

  bool get complet => affectations.length >= nombreRequis;
}

/// Militaires proposes pour le garnissage des postes et roles.
class MilitaireOption {
  final int id;
  final String nom;
  final String? gradeLibelle;
  final int? gradeId;

  final String? gradeCode;

  const MilitaireOption({
    required this.id,
    required this.nom,
    this.gradeLibelle,
    this.gradeCode,
    this.gradeId,
  });

  String get nomAffichage =>
      [gradeCode ?? gradeLibelle, nom].whereType<String>().join(' ').trim();
}

/// Definition d'un role d'astreinte cree par defaut.
class RoleAstreinteDef {
  final String code;
  final String libelle;
  final int nombre;
  const RoleAstreinteDef(this.code, this.libelle, this.nombre);
}

/// Roles crees par defaut pour un service d'astreinte.
const List<RoleAstreinteDef> kRolesAstreinte = [
  RoleAstreinteDef('OFF_PERM', 'Officier de permanence', 1),
  RoleAstreinteDef('SOFF_PERM', 'Sous-officier de permanence', 1),
  RoleAstreinteDef('RESP_ARMEMENT', 'Responsable armement', 1),
  RoleAstreinteDef('RESERVE', 'Réserve', 6),
];

/// Types de QRF proposes a la creation.
class TypeQrf {
  TypeQrf._();
  static const String piquet = 'PIQUET';
  static const String intervention = 'INTERVENTION';
}

const Map<String, String> kTypesQrf = {
  'PIQUET': 'Piquet',
  'INTERVENTION': 'Intervention',
};

/// Modes de composition d'une QRF.
class ModeQrf {
  ModeQrf._();
  static const String liste = 'LISTE';
  static const String equipage = 'EQUIPAGE';
}

const Map<String, String> kModesQrf = {
  'LISTE': 'Liste (effectif à définir)',
  'EQUIPAGE': 'Par équipage',
};

/// Fonctions d'un equipage d'engin blinde.
class FonctionEquipage {
  FonctionEquipage._();
  static const String chefEngin = 'CE';
  static const String pilote = 'P';
  static const String tireur = 'T';
  static const String cavalierPorte = 'CP';
  static const String chargeur = 'CHARGEUR';
  static const String equipier = 'EQUIPIER';
}

const Map<String, String> kFonctionEquipageLibelle = {
  'CE': "Chef d'engin",
  'P': 'Pilote',
  'T': 'Tireur',
  'CP': 'Cavalier porté',
  'CHARGEUR': 'Chargeur',
  'EQUIPIER': 'Équipier',
};

/// Composition d'equipage d'un engin blinde.
class EnginBlinde {
  final String code;
  final String libelle;
  final List<String> fonctions;
  const EnginBlinde(this.code, this.libelle, this.fonctions);
  int get effectif => fonctions.length;
}

const List<EnginBlinde> kEnginsBlindes = [
  EnginBlinde('WMZ', 'WMZ', ['CE', 'P', 'T', 'CP', 'CP', 'CP']),
  EnginBlinde('VN22B', 'VN22B', ['CE', 'P', 'T', 'CHARGEUR']),
  EnginBlinde('PUMA_M36', 'PUMA M36', ['CE', 'P', 'T', 'CP', 'CP', 'CP']),
];

EnginBlinde? enginParCode(String? code) {
  for (final e in kEnginsBlindes) {
    if (e.code == code) return e;
  }
  return null;
}

/// Regroupement des fonctions d'un equipage (ex. 3 cavaliers portes).
class GroupeFonction {
  final String fonction;
  final int nombre;
  const GroupeFonction(this.fonction, this.nombre);
}

/// Regroupe des fonctions d'equipage par metier en conservant l'ordre
/// d'apparition (ex. WMZ -> CE x1, P x1, T x1, CP x3).
List<GroupeFonction> groupesFonction(List<String> fonctions) {
  final ordre = <String>[];
  final compte = <String, int>{};
  for (final f in fonctions) {
    if (!compte.containsKey(f)) ordre.add(f);
    compte[f] = (compte[f] ?? 0) + 1;
  }
  return [for (final f in ordre) GroupeFonction(f, compte[f]!)];
}

/// Encode les grades autorises par fonction d'equipage en JSON
/// (les fonctions sans restriction ne sont pas stockees).
String encoderGradesFonctions(Map<String, Set<int>> grades) {
  final map = <String, List<int>>{};
  for (final e in grades.entries) {
    if (e.value.isEmpty) continue;
    map[e.key] = e.value.toList()..sort();
  }
  return jsonEncode(map);
}

/// Decode les grades autorises par fonction d'equipage.
Map<String, Set<int>> decoderGradesFonctions(Object? brut) {
  if (brut is! String || brut.trim().isEmpty) return {};
  try {
    final decoded = jsonDecode(brut);
    if (decoded is! Map) return {};
    final res = <String, Set<int>>{};
    decoded.forEach((k, v) {
      if (v is List) {
        res['$k'] =
            v.whereType<num>().map((e) => e.toInt()).toSet();
      }
    });
    return res;
  } catch (_) {
    return {};
  }
}

/// Un membre d'une QRF (une fonction tenue par un militaire).
class ServiceQrfMembre {
  int? id;
  int? qrfId;
  String fonction;
  int? militaireId;
  String? militaireNom;
  String? gradeCode;

  /// Numero d'equipage auquel le membre appartient (1 par defaut).
  int equipage;
  int ordre;

  ServiceQrfMembre({
    this.id,
    this.qrfId,
    required this.fonction,
    this.militaireId,
    this.militaireNom,
    this.gradeCode,
    this.equipage = 1,
    this.ordre = 0,
  });

  factory ServiceQrfMembre.fromMap(Map<String, Object?> m) => ServiceQrfMembre(
        id: m['id'] as int?,
        qrfId: m['qrf_id'] as int?,
        fonction: (m['fonction'] ?? FonctionEquipage.equipier) as String,
        militaireId: m['militaire_id'] as int?,
        militaireNom: m['militaire_nom'] as String?,
        gradeCode: m['grade_code'] as String?,
        equipage: (m['equipage'] as int?) ?? 1,
        ordre: (m['ordre'] as int?) ?? 0,
      );

  String get fonctionLibelle => kFonctionEquipageLibelle[fonction] ?? fonction;

  String get nomAffichage =>
      [gradeCode, militaireNom].whereType<String>().join(' ').trim();
}

/// Une QRF (Piquet / Intervention), composee en liste ou par equipage.
class ServiceQrf {
  int? id;
  int? serviceId;
  String type;
  String mode;
  String? engin;
  int effectif;

  /// Nombre d'equipages regroupes dans cette QRF (mode equipage).
  int nombreEquipages;
  int ordre;
  List<ServiceQrfMembre> membres;

  /// Grades autorises par poste (fonction) de l'equipage. Un metier absent
  /// ou associe a un ensemble vide signifie "tous grades".
  Map<String, Set<int>> gradesFonctions;

  ServiceQrf({
    this.id,
    this.serviceId,
    this.type = 'PIQUET',
    this.mode = 'LISTE',
    this.engin,
    this.effectif = 0,
    this.nombreEquipages = 1,
    this.ordre = 0,
    List<ServiceQrfMembre>? membres,
    Map<String, Set<int>>? gradesFonctions,
  })  : membres = membres ?? [],
        gradesFonctions = gradesFonctions ?? {};

  factory ServiceQrf.fromMap(Map<String, Object?> m) => ServiceQrf(
        id: m['id'] as int?,
        serviceId: m['service_id'] as int?,
        type: (m['type'] ?? 'PIQUET') as String,
        mode: (m['mode'] ?? 'LISTE') as String,
        engin: m['engin'] as String?,
        effectif: (m['effectif'] as int?) ?? 0,
        nombreEquipages: (m['nombre_equipages'] as int?) ?? 1,
        ordre: (m['ordre'] as int?) ?? 0,
        gradesFonctions: decoderGradesFonctions(m['grades_fonctions']),
      );

  bool get estEquipage => mode == ModeQrf.equipage;

  EnginBlinde? get enginInfo => enginParCode(engin);

  /// Grades autorises pour un poste (fonction) : vide = tous grades.
  Set<int> gradesPourFonction(String fonction) =>
      gradesFonctions[fonction] ?? const <int>{};

  String get gradesFonctionsJson => encoderGradesFonctions(gradesFonctions);

  int get effectifRequis => estEquipage
      ? nombreEquipages * (enginInfo?.effectif ?? 0)
      : effectif;

  bool get complet => membres.length >= effectifRequis;

  /// Numeros d'equipage presents, dans l'ordre croissant.
  List<int> get numerosEquipages {
    final nums = <int>{for (final m in membres) m.equipage};
    final res = nums.toList()..sort();
    return res;
  }

  /// Membres rattaches a un equipage donne.
  List<ServiceQrfMembre> membresEquipage(int numero) =>
      membres.where((m) => m.equipage == numero).toList();

  int get effectifEquipage => enginInfo?.effectif ?? 0;

  String get titre => 'QRF ${kTypesQrf[type] ?? type}';

  String get sousTitre {
    if (estEquipage) {
      final eng = enginInfo?.libelle ?? engin ?? 'Équipage';
      final bloc = nombreEquipages > 1
          ? '$nombreEquipages équipages $eng'
          : 'Équipage $eng';
      return '$bloc (${membres.length}/$effectifRequis)';
    }
    return 'Liste (${membres.length}/$effectif)';
  }
}

/// Composition d'un service (postes + roles) pour les exports.
class AstreinteData {
  final ServiceModel service;
  final List<ServicePoste> principaux;
  final List<ServiceRole> roles;
  final List<ServiceQrf> qrfs;

  const AstreinteData({
    required this.service,
    required this.principaux,
    required this.roles,
    this.qrfs = const [],
  });

  String get titre =>
      '${service.nom}${(service.posteLibelle ?? '').isEmpty ? '' : ' - ${service.posteLibelle}'}';

  String get titreDocument => service.estAstreinte
      ? "COMPOSITION DE L'ASTREINTE"
      : 'COMPOSITION DU SERVICE';

  String get sousTitre {
    final creneau = [service.creneauDebut, service.creneauFin]
        .whereType<String>()
        .join('-');
    return creneau.isEmpty ? service.date : '${service.date}   $creneau';
  }

  /// Representation a plat, commune aux exports PDF/Excel/Word.
  /// Colonnes : [Rubrique / Poste, Effectif, Personnel / Detail].
  List<List<String>> lignes() {
    final rows = <List<String>>[];
    if (roles.isNotEmpty) {
      rows.add(["RÔLES DE L'ASTREINTE", '', '']);
      for (final r in roles) {
        rows.add([
          r.libelle,
          '${r.affectations.length}/${r.nombreRequis}',
          r.affectations.map((a) => a.nomAffichage).join(', '),
        ]);
      }
    }
    rows.add(['POSTES PRINCIPAUX', '', '']);
    for (final p in principaux) {
      rows.add([p.libelle, '', '']);
      rows.add(['Chef de poste', '', p.chef?.nomAffichage ?? '—']);
      rows.add(['Adjoint', '', p.adjoint?.nomAffichage ?? '—']);
      for (final e in p.enfants) {
        final effectif = e.effectifRequis == null
            ? '${e.effectifFaction}'
            : '${e.effectifFaction}/${e.effectifRequis}';
        final creneau = (e.creneauDebut != null || e.creneauFin != null)
            ? '${e.creneauDebut ?? ''}-${e.creneauFin ?? ''}  '
            : '';
        final boucle = service.debutDt;
        if (service.estAstreinte && boucle != null && e.faction.isNotEmpty) {
          final creneaux = creneauxFaction2h(
            debut: boucle,
            dureeHeures: service.dureeHeures,
            faction: e.faction,
          );
          var premier = true;
          for (final c in creneaux) {
            rows.add([
              premier ? '- ${e.libelle}' : '',
              premier ? effectif : '',
              '${hm(c.debut)}-${hm(c.fin)}  ${c.affectation?.nomAffichage ?? ''}',
            ]);
            premier = false;
          }
        } else {
          final faction = e.faction.map((a) => a.nomAffichage).join(', ');
          rows.add(['- ${e.libelle}', effectif, '$creneau$faction']);
        }
      }
    }
    if (qrfs.isNotEmpty) {
      rows.add(['QRF', '', '']);
      for (final q in qrfs) {
        rows.add([q.titre, '', q.sousTitre]);
        if (q.estEquipage && q.nombreEquipages > 1) {
          final eng = q.enginInfo?.libelle ?? q.engin ?? '';
          for (var e = 1; e <= q.nombreEquipages; e++) {
            final membres = q.membresEquipage(e);
            rows.add([
              'Équipage $e ($eng)',
              '${membres.length}/${q.effectifEquipage}',
              '',
            ]);
            for (final m in membres) {
              rows.add([m.fonctionLibelle, '', m.nomAffichage]);
            }
          }
        } else {
          for (final m in q.membres) {
            rows.add([m.fonctionLibelle, '', m.nomAffichage]);
          }
        }
      }
    }
    return rows;
  }
}
