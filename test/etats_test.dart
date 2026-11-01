import 'package:flutter_test/flutter_test.dart';

import 'package:gpm_ebc/core/etats.dart';
import 'package:gpm_ebc/models/personnel.dart';

Personnel _p(int id, String categorie, {bool dispo = true}) {
  final p = Personnel(id: id, nomPrenoms: 'M$id', disponible: dispo);
  p.categorieLibelle = categorie;
  return p;
}

void main() {
  group('categorieDe', () {
    test('renvoie le libelle de categorie', () {
      expect(categorieDe(_p(1, 'Officier')), 'Officier');
    });

    test('renvoie "Non precise" quand vide', () {
      expect(categorieDe(_p(1, '')), 'Non precise');
    });
  });

  group('ordreCategorie', () {
    test('ordonne officier < sous-officier < MDR < autres', () {
      expect(ordreCategorie('Officier') < ordreCategorie('Sous-officier'), isTrue);
      expect(
        ordreCategorie('Sous-officier') < ordreCategorie('Militaire du rang'),
        isTrue,
      );
      expect(
        ordreCategorie('Militaire du rang') < ordreCategorie('Autre'),
        isTrue,
      );
    });
  });

  group('vivierProposition', () {
    final membres = [
      _p(1, 'Officier'),
      _p(2, 'Officier', dispo: false),
      _p(3, 'Militaire du rang'),
      _p(4, 'Militaire du rang', dispo: false),
    ];

    test('disponiblesAvecFaction inclut les indisponibles de faction', () {
      final v = vivierProposition(
        membres,
        FiltreProposition.disponiblesAvecFaction,
        deFaction: {2},
      );
      expect(v.map((p) => p.id), [1, 2, 3]);
    });

    test('disponiblesHorsFaction exclut les personnes de faction', () {
      final v = vivierProposition(
        membres,
        FiltreProposition.disponiblesHorsFaction,
        deFaction: {1},
      );
      expect(v.map((p) => p.id), [3]);
    });

    test('factionUniquement ne retient que les personnes de faction', () {
      final v = vivierProposition(
        membres,
        FiltreProposition.factionUniquement,
        deFaction: {2, 4},
      );
      expect(v.map((p) => p.id), [2, 4]);
    });

    test('tous renvoie tout le monde', () {
      final v = vivierProposition(membres, FiltreProposition.tous);
      expect(v.length, 4);
    });
  });

  group('proposerListe', () {
    final membres = [
      _p(1, 'Officier'),
      _p(2, 'Officier'),
      _p(3, 'Officier'),
      _p(4, 'Sous-officier'),
      _p(5, 'Sous-officier'),
      _p(6, 'Militaire du rang'),
      _p(7, 'Militaire du rang'),
      _p(8, 'Militaire du rang'),
    ];

    test('respecte le nombre par categorie', () {
      final liste = proposerListe(
        membres: membres,
        demande: const PropositionDemande(
          total: 0,
          parCategorie: {'Officier': 1, 'Militaire du rang': 2},
        ),
      );
      expect(liste.where((p) => categorieDe(p) == 'Officier').length, 1);
      expect(liste.where((p) => categorieDe(p) == 'Militaire du rang').length, 2);
      expect(liste.length, 3);
    });

    test('completes le total sans depasser', () {
      final liste = proposerListe(
        membres: membres,
        demande: const PropositionDemande(
          total: 5,
          parCategorie: {'Officier': 1},
        ),
      );
      expect(liste.length, 5);
      expect(liste.first.id, 1);
    });

    test('ne depasse pas la taille du vivier', () {
      final liste = proposerListe(
        membres: membres,
        demande: const PropositionDemande(total: 100),
      );
      expect(liste.length, 8);
    });

    test('suit le filtre de disponibilite', () {
      final melange = [
        _p(1, 'Officier'),
        _p(2, 'Officier', dispo: false),
      ];
      final liste = proposerListe(
        membres: melange,
        demande: const PropositionDemande(
          total: 2,
          filtre: FiltreProposition.disponiblesHorsFaction,
        ),
      );
      expect(liste.map((p) => p.id), [1]);
    });
  });

  group('remplacantPour', () {
    final membres = [
      _p(1, 'Officier'),
      _p(2, 'Officier'),
      _p(3, 'Sous-officier'),
    ];

    test('renvoie un remplacant de meme categorie non deja selectionne', () {
      final selection = [membres[0]];
      final remplacant = remplacantPour(
        remplace: membres[0],
        selection: selection,
        membres: membres,
      );
      expect(remplacant?.id, 2);
      expect(categorieDe(remplacant!), 'Officier');
    });

    test('renvoie null quand aucun remplacant disponible', () {
      final selection = [membres[0], membres[1]];
      final remplacant = remplacantPour(
        remplace: membres[0],
        selection: selection,
        membres: membres,
      );
      expect(remplacant, isNull);
    });
  });
}
