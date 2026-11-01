import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpm_ebc/models/service.dart';
import 'package:gpm_ebc/services/pdf_service.dart';
import 'package:gpm_ebc/services/word_service.dart';

AffectationService _aff(int id, String role, {int? posteId}) => AffectationService(
      id: id,
      militaireId: id,
      militaireNom: 'M$id',
      roleService: role,
      servicePosteId: posteId,
    );

void main() {
  test('arborescence rattache les postes basiques a leur principal', () {
    final plats = [
      ServicePoste(id: 1, libelle: 'Poste A', type: TypePoste.principal, ordre: 0),
      ServicePoste(id: 2, libelle: 'Porte', parentId: 1, ordre: 0),
      ServicePoste(id: 3, libelle: 'Tour', parentId: 1, ordre: 1),
      ServicePoste(id: 4, libelle: 'Poste B', type: TypePoste.principal, ordre: 1),
      ServicePoste(id: 5, libelle: 'Magasin', parentId: 4, ordre: 0),
    ];
    final arbre = ServicePoste.arborescence(plats);
    expect(arbre.map((p) => p.libelle), ['Poste A', 'Poste B']);
    expect(arbre.first.enfants.map((e) => e.libelle), ['Porte', 'Tour']);
    expect(arbre.last.enfants.single.libelle, 'Magasin');
    expect(arbre.first.estPrincipal, isTrue);
    expect(arbre.first.enfants.first.estPrincipal, isFalse);
  });

  test('chef, adjoint et faction sont distingues par role', () {
    final poste = ServicePoste(id: 1, libelle: 'Poste A', type: TypePoste.principal)
      ..affectations = [
        _aff(1, 'CHEF_POSTE', posteId: 1),
        _aff(2, 'ADJOINT', posteId: 1),
      ];
    expect(poste.chef?.militaireId, 1);
    expect(poste.adjoint?.militaireId, 2);
    expect(poste.faction, isEmpty);
  });

  test('complet verifie l effectif requis de la faction', () {
    final basique = ServicePoste(id: 2, libelle: 'Porte', effectifRequis: 2)
      ..affectations = [_aff(1, 'FACTION', posteId: 2)];
    expect(basique.effectifFaction, 1);
    expect(basique.complet, isFalse);
    basique.affectations.add(_aff(3, 'FACTION', posteId: 2));
    expect(basique.effectifFaction, 2);
    expect(basique.complet, isTrue);
  });

  test('sans effectif requis le poste est considere complet', () {
    final basique = ServicePoste(id: 2, libelle: 'Porte');
    expect(basique.complet, isTrue);
  });

  test('ServiceRole.complet compare affectations et nombre requis', () {
    final role = ServiceRole(libelle: 'QRF', nombreRequis: 2);
    expect(role.complet, isFalse);
    role.affectations.add(_aff(1, 'ASTREINTE'));
    expect(role.complet, isFalse);
    role.affectations.add(_aff(2, 'ASTREINTE'));
    expect(role.complet, isTrue);
  });

  test('ServiceModel conserve la duree et la date de fin', () {
    final s = ServiceModel(
      date: '2026-01-01',
      creneauDebut: '06:00',
      creneauFin: '06:00',
      dureeHeures: 48,
      dateFin: '2026-01-03',
    );
    final m = s.toMap();
    expect(m['duree_heures'], 48);
    expect(m['date_fin'], '2026-01-03');
    final r = ServiceModel.fromMap({...m, 'id': 1});
    expect(r.dureeHeures, 48);
    expect(r.dateFin, '2026-01-03');
    expect(ServiceModel(date: '2026-01-01').dureeHeures, 24);
  });

  test('ServiceModel.nom utilise le libelle libre sinon le type', () {
    expect(ServiceModel(date: '2026-01-01', typeLibelle: 'Astreinte').nom,
        'Astreinte');
    expect(
        ServiceModel(
                date: '2026-01-01',
                typeLibelle: 'Autre service',
                libelle: 'Cérémonie')
            .nom,
        'Cérémonie');
    expect(
        ServiceModel(
                date: '2026-01-01', typeLibelle: 'Autre service', libelle: '   ')
            .nom,
        'Autre service');
    expect(ServiceModel(date: '2026-01-01').nom, 'Service');
  });

  test('creneaux de faction 2h en boucle round-robin sur la duree', () {
    final faction = [_aff(1, 'FACTION'), _aff(2, 'FACTION'), _aff(3, 'FACTION')];
    final debut = DateTime(2026, 1, 1, 6);
    final c = creneauxFaction2h(debut: debut, dureeHeures: 24, faction: faction);
    expect(c.length, 12);
    expect(hm(c.first.debut), '06:00');
    expect(hm(c.first.fin), '08:00');
    expect(c.map((e) => e.affectation?.militaireId).take(4), [1, 2, 3, 1]);
    expect(hm(c.last.debut), '04:00');
    expect(hm(c.last.fin), '06:00');
    final c48 =
        creneauxFaction2h(debut: debut, dureeHeures: 48, faction: faction);
    expect(c48.length, 24);
    expect(
        creneauxFaction2h(debut: debut, dureeHeures: 24, faction: const []),
        isEmpty);
  });

  test('un service d astreinte est reconnu par son code de type', () {
    expect(ServiceModel(date: '2026-01-01', typeCode: 'ASTREINTE').estAstreinte, isTrue);
    expect(ServiceModel(date: '2026-01-01', typeCode: 'GARDE').estAstreinte, isFalse);
  });

  AstreinteData exemple() {
    final principal = ServicePoste(
      id: 1,
      libelle: 'Poste PC',
      type: TypePoste.principal,
    )..affectations = [
        AffectationService(militaireId: 10, militaireNom: 'ALPHA', roleService: 'CHEF_POSTE'),
        AffectationService(militaireId: 11, militaireNom: 'BRAVO', roleService: 'ADJOINT'),
      ];
    final basique = ServicePoste(
      id: 2,
      parentId: 1,
      libelle: 'Porte principale',
      effectifRequis: 2,
    )..affectations = [
        AffectationService(militaireId: 12, militaireNom: 'CHARLIE', roleService: 'FACTION'),
      ];
    principal.enfants = [basique];
    final role = ServiceRole(libelle: 'QRF', nombreRequis: 2)
      ..affectations = [
        AffectationService(militaireId: 20, militaireNom: 'DELTA', roleService: 'ASTREINTE'),
      ];
    return AstreinteData(
      service: ServiceModel(
        date: '2026-01-01',
        creneauDebut: '06:00',
        creneauFin: '18:00',
        typeCode: 'ASTREINTE',
        typeLibelle: 'Astreinte',
      ),
      principaux: [principal],
      roles: [role],
    );
  }

  test('lignes compose roles, chef/adjoint et faction', () {
    final lignes = exemple().lignes();
    final texte = lignes.map((l) => l.join(' | ')).join('\n');
    expect(texte, contains('QRF | 1/2'));
    expect(texte, contains('DELTA'));
    expect(texte, contains('Chef de poste |  | ALPHA'));
    expect(texte, contains('Adjoint |  | BRAVO'));
    expect(texte, contains('- Porte principale | 1/2'));
    expect(texte, contains('CHARLIE'));
  });

  test('engins blindes ont la composition d equipage attendue', () {
    expect(enginParCode('WMZ')!.effectif, 6);
    expect(
        enginParCode('WMZ')!.fonctions, ['CE', 'P', 'T', 'CP', 'CP', 'CP']);
    expect(enginParCode('VN22B')!.fonctions, ['CE', 'P', 'T', 'CHARGEUR']);
    expect(enginParCode('PUMA_M36')!.effectif, 6);
    expect(enginParCode('INCONNU'), isNull);
  });

  test('QRF par equipage expose son effectif requis et sa completude', () {
    final qrf = ServiceQrf(
      type: TypeQrf.intervention,
      mode: ModeQrf.equipage,
      engin: 'WMZ',
    )..membres = [
        ServiceQrfMembre(fonction: 'CE', militaireId: 1, militaireNom: 'X'),
      ];
    expect(qrf.effectifRequis, 6);
    expect(qrf.complet, isFalse);
    expect(qrf.titre, 'QRF Intervention');
  });

  test('QRF regroupe plusieurs equipages dans un seul bloc', () {
    final qrf = ServiceQrf(
      type: TypeQrf.intervention,
      mode: ModeQrf.equipage,
      engin: 'WMZ',
      nombreEquipages: 2,
    )..membres = [
        ServiceQrfMembre(fonction: 'CE', militaireId: 1, equipage: 1),
        ServiceQrfMembre(fonction: 'CE', militaireId: 2, equipage: 2),
      ];
    expect(qrf.effectifRequis, 12);
    expect(qrf.effectifEquipage, 6);
    expect(qrf.numerosEquipages, [1, 2]);
    expect(qrf.membresEquipage(1).single.militaireId, 1);
    expect(qrf.membresEquipage(2).single.militaireId, 2);
    expect(qrf.sousTitre, '2 équipages WMZ (2/12)');
    expect(qrf.complet, isFalse);
  });

  test('export regroupe les membres par equipage', () {
    final qrf = ServiceQrf(
      type: TypeQrf.intervention,
      mode: ModeQrf.equipage,
      engin: 'WMZ',
      nombreEquipages: 2,
    )..membres = [
        ServiceQrfMembre(
            fonction: 'CE', militaireId: 1, militaireNom: 'X', equipage: 1),
        ServiceQrfMembre(
            fonction: 'CE', militaireId: 2, militaireNom: 'Y', equipage: 2),
      ];
    final data = AstreinteData(
      service: ServiceModel(date: '2026-01-01', typeCode: 'ASTREINTE'),
      principaux: const [],
      roles: const [],
      qrfs: [qrf],
    );
    final texte = data.lignes().map((l) => l.join(' | ')).join('\n');
    expect(texte, contains('Équipage 1 (WMZ) | 1/6'));
    expect(texte, contains('Équipage 2 (WMZ) | 1/6'));
    expect(texte, contains('Chef d\'engin |  | X'));
    expect(texte, contains('Chef d\'engin |  | Y'));
  });

  test('groupesFonction regroupe les cavaliers portes par equipage', () {
    final g = groupesFonction(enginParCode('WMZ')!.fonctions);
    expect(g.map((e) => e.fonction), ['CE', 'P', 'T', 'CP']);
    expect(g.map((e) => e.nombre), [1, 1, 1, 3]);
    final vn = groupesFonction(enginParCode('VN22B')!.fonctions);
    expect(vn.map((e) => e.nombre), [1, 1, 1, 1]);
  });

  test('grades par poste d un equipage : encodage et lecture', () {
    final qrf = ServiceQrf(
      type: TypeQrf.intervention,
      mode: ModeQrf.equipage,
      engin: 'WMZ',
      gradesFonctions: {
        'CE': {3, 4},
        'CP': {7},
      },
    );
    expect(qrf.gradesPourFonction('CE'), {3, 4});
    expect(qrf.gradesPourFonction('CP'), {7});
    expect(qrf.gradesPourFonction('P'), isEmpty);
    final relu = ServiceQrf.fromMap(
        {'id': 1, 'engin': 'WMZ', 'grades_fonctions': qrf.gradesFonctionsJson});
    expect(relu.gradesPourFonction('CE'), {3, 4});
    expect(relu.gradesPourFonction('CP'), {7});
    expect(decoderGradesFonctions('invalide'), isEmpty);
    expect(decoderGradesFonctions(null), isEmpty);
  });

  test('l ancien role d astreinte QRF n est plus cree par defaut', () {
    expect(kRolesAstreinte.any((r) => r.code == 'QRF'), isFalse);
  });

  test('lignes incluent les QRF', () {
    final qrf = ServiceQrf(
      type: TypeQrf.piquet,
      mode: ModeQrf.liste,
      effectif: 3,
    )..membres = [
        ServiceQrfMembre(
            fonction: 'EQUIPIER',
            militaireId: 1,
            militaireNom: 'ECHO',
            gradeCode: 'ADT'),
      ];
    final data = AstreinteData(
      service: ServiceModel(date: '2026-01-01', typeCode: 'ASTREINTE'),
      principaux: const [],
      roles: const [],
      qrfs: [qrf],
    );
    final texte = data.lignes().map((l) => l.join(' | ')).join('\n');
    expect(texte, contains('QRF Piquet'));
    expect(texte, contains('QRF Piquet |  | Liste (1/3)'));
    expect(texte, contains('Équipier |  | ADT ECHO'));
  });

  test('grades autorises par responsabilite et par role', () {
    final poste =
        ServicePoste(id: 1, libelle: 'Poste A', type: TypePoste.principal)
          ..gradesAutorises = {
            CibleGrade.chef: {3, 4},
            CibleGrade.adjoint: {5},
          };
    expect(poste.gradesChef, {3, 4});
    expect(poste.gradesAdjoint, {5});
    expect(poste.gradesFaction, isEmpty);
    expect(poste.gradesPour(CibleGrade.faction), isEmpty);

    final role = ServiceRole(libelle: 'QRF')..gradesAutorises = {7};
    expect(role.gradesAutorises, {7});
  });

  test('MilitaireOption conserve le grade', () {
    const m = MilitaireOption(
        id: 1, nom: 'DUPONT', gradeLibelle: 'Sergent', gradeId: 42);
    expect(m.gradeId, 42);
  });

  test('export PDF de la composition de l astreinte', () async {
    final bytes = await PdfService.astreinte(exemple());
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('export Word de la composition de l astreinte', () {
    final bytes = WordService.construireAstreinteBytes(exemple());
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = archive.files.firstWhere((f) => f.name == 'word/document.xml');
    final xml = utf8.decode(doc.content as List<int>);
    expect(xml, contains('COMPOSITION'));
    expect(xml, contains('QRF'));
    expect(xml, contains('Porte principale'));
    expect(xml, contains('ALPHA'));
  });
}
