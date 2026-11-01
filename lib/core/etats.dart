import 'package:flutter/material.dart';

import '../models/personnel.dart';
import 'positions.dart';

/// Types d'etats que le Commandant peut creer, avec le filtre de personnel
/// concerne (statuts / disponibilite) pour l'affichage dans l'onglet Effectifs.
class EtatOption {
  final String code;
  final String libelle;
  final IconData icone;
  final List<String> statutCodes;
  final bool? disponible;

  const EtatOption({
    required this.code,
    required this.libelle,
    required this.icone,
    this.statutCodes = const [],
    this.disponible,
  });
}

const Map<String, IconData> _iconesParPosition = {
  'Présent': Icons.check_circle,
  'Mission': Icons.flight_takeoff,
  'Stage': Icons.school,
  'Mise a disposition': Icons.assignment_ind,
  'Permission': Icons.beach_access,
  'Malade': Icons.sick,
  'Repos': Icons.hotel,
  'Absent': Icons.person_off,
};

/// Options de "Creer un etat" : strictement les 8 positions (rubriques) du
/// volet "Repartition du personnel", auxquelles elles sont liees.
final List<EtatOption> kEtats = kPositions
    .map((position) => EtatOption(
          code: position,
          libelle: position,
          icone: _iconesParPosition[position] ?? Icons.event_note,
          statutCodes: [statutCodeDepuisPosition(position)],
        ))
    .toList();

/// Anciens codes d'etats (avant alignement sur les 8 positions).
const Map<String, String> _anciensCodes = {
  'CEREMONIE': 'Présent',
  'MISSION': 'Mission',
  'STAGE': 'Stage',
  'MISE_A_DISPOSITION': 'Mise a disposition',
  'PERMISSION': 'Permission',
  'MALADE': 'Malade',
  'REPOS': 'Repos',
  'ABSENT': 'Absent',
};

String etatLibelle(String? code) {
  if (code == null || code.isEmpty) return 'Etat';
  for (final e in kEtats) {
    if (e.code == code || e.libelle == code) return e.libelle;
  }
  return _anciensCodes[code.toUpperCase()] ?? code;
}

// ---------------------------------------------------------------------------
// Composition d'un etat : "liste" (selection libre) ou "changement de
// position" (configuration courante).
// ---------------------------------------------------------------------------

/// Mode de composition choisi depuis "Creer un etat".
enum ModeEtat {
  /// Liste nommee : selection libre du personnel, avec proposition possible.
  liste,

  /// Changement de position : applique une position aux personnes choisies.
  position,
}

/// Type d'etat historise pour une liste nommee.
const String kTypeListe = 'LISTE';

/// Libelle affichable du type d'un etat (gere la liste nommee en plus des
/// 8 positions).
String etatTypeLibelle(String? type) {
  if ((type ?? '').toUpperCase() == kTypeListe) return 'Liste';
  return etatLibelle(type);
}

/// Filtre du vivier de candidats pour une proposition de liste.
enum FiltreProposition {
  /// Disponibles, personnes de faction comprises (defaut).
  disponiblesAvecFaction,

  /// Disponibles hors personnes actuellement de faction.
  disponiblesHorsFaction,

  /// Uniquement les personnes actuellement de faction.
  factionUniquement,

  /// Tous les membres, sans filtre.
  tous,
}

/// Libelles des filtres de proposition.
const Map<FiltreProposition, String> kFiltresProposition = {
  FiltreProposition.disponiblesAvecFaction: 'Disponibles (factions comprises)',
  FiltreProposition.disponiblesHorsFaction: 'Disponibles hors faction',
  FiltreProposition.factionUniquement: 'Personnes de faction',
  FiltreProposition.tous: 'Tous les membres',
};

/// Demande de proposition : nombre total et nombre par categorie de grade.
class PropositionDemande {
  final int total;
  final Map<String, int> parCategorie;
  final FiltreProposition filtre;
  const PropositionDemande({
    required this.total,
    this.parCategorie = const {},
    this.filtre = FiltreProposition.disponiblesAvecFaction,
  });
}

/// Categorie statutaire d'un militaire (libelle) ou "Non precise".
String categorieDe(Personnel p) {
  final libelle = (p.categorieLibelle ?? '').trim();
  return libelle.isEmpty ? 'Non precise' : libelle;
}

/// Ordre d'affichage des categories de grade (officier > sous-officier > MDR).
int ordreCategorie(String categorie) {
  switch (categorie.toUpperCase()) {
    case 'OFFICIER':
      return 0;
    case 'SOUS-OFFICIER':
      return 1;
    case 'MILITAIRE DU RANG':
      return 2;
    default:
      return 3;
  }
}

/// Vivier de candidats retenus par [filtre].
List<Personnel> vivierProposition(
  List<Personnel> membres,
  FiltreProposition filtre, {
  Set<int> deFaction = const {},
}) {
  bool enFaction(Personnel p) => p.id != null && deFaction.contains(p.id);
  switch (filtre) {
    case FiltreProposition.disponiblesAvecFaction:
      return membres.where((p) => p.disponible || enFaction(p)).toList();
    case FiltreProposition.disponiblesHorsFaction:
      return membres.where((p) => p.disponible && !enFaction(p)).toList();
    case FiltreProposition.factionUniquement:
      return membres.where(enFaction).toList();
    case FiltreProposition.tous:
      return List<Personnel>.from(membres);
  }
}

/// Propose une liste respectant la composition demandee (nombre par categorie
/// puis, si besoin, completion jusqu'au total). L'ordre suit [membres].
List<Personnel> proposerListe({
  required List<Personnel> membres,
  required PropositionDemande demande,
  Set<int> deFaction = const {},
}) {
  final pool = vivierProposition(membres, demande.filtre, deFaction: deFaction);
  final choisis = <Personnel>[];
  final pris = <int>{};

  void ajouter(Personnel p) {
    choisis.add(p);
    if (p.id != null) pris.add(p.id!);
  }

  final categories = demande.parCategorie.keys.toList()
    ..sort((a, b) => ordreCategorie(a).compareTo(ordreCategorie(b)));
  for (final cat in categories) {
    var reste = demande.parCategorie[cat] ?? 0;
    if (reste <= 0) continue;
    for (final p in pool) {
      if (reste == 0) break;
      if (p.id != null && pris.contains(p.id)) continue;
      if (categorieDe(p) != cat) continue;
      ajouter(p);
      reste--;
    }
  }

  final total = demande.total > 0 ? demande.total : choisis.length;
  for (final p in pool) {
    if (choisis.length >= total) break;
    if (p.id != null && pris.contains(p.id)) continue;
    ajouter(p);
  }
  return choisis;
}

/// Cherche un remplacant pour [remplace] : meme categorie, present dans le
/// vivier, non deja present dans [selection].
Personnel? remplacantPour({
  required Personnel remplace,
  required List<Personnel> selection,
  required List<Personnel> membres,
  Set<int> deFaction = const {},
  FiltreProposition filtre = FiltreProposition.disponiblesAvecFaction,
}) {
  final pool = vivierProposition(membres, filtre, deFaction: deFaction);
  final pris = selection.map((p) => p.id).whereType<int>().toSet();
  final cat = categorieDe(remplace);
  for (final p in pool) {
    if (p.id == null || pris.contains(p.id)) continue;
    if (categorieDe(p) != cat) continue;
    return p;
  }
  return null;
}
