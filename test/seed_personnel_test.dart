import 'package:flutter_test/flutter_test.dart';
import 'package:gpm_ebc/data/seed_personnel.dart';

void main() {
  test('kSeedPersonnel contient les 95 militaires du fichier principal', () {
    expect(kSeedPersonnel.length, 95);
  });

  test('premier et dernier enregistrements corrects', () {
    expect(kSeedPersonnel.first['nom'], 'KOFFI KPANGNI OSKINS PRIVAT');
    expect(kSeedPersonnel.first['grade'], 'CNE');
    expect(kSeedPersonnel.first['matricule'], '001 09 001359');
    expect(kSeedPersonnel.last['nom'], 'DEHO BERENGER STEPHANE');
    expect(kSeedPersonnel.last['grade'], 'CLIER2');
  });

  test('tous les grades presents dans le fichier sont couverts', () {
    final grades = kSeedPersonnel.map((p) => p['grade']).toSet();
    expect(
      grades.containsAll(
          {'CNE', 'LTN', 'ADT', 'MDC', 'MDL', 'BIER', 'CLIER1', 'CLIER2'}),
      isTrue,
      reason: 'grades trouves: $grades',
    );
  });

  test('chaque militaire possede un nom et une categorie', () {
    for (final p in kSeedPersonnel) {
      expect((p['nom'] ?? '').isNotEmpty, isTrue);
      expect(
        {'OFF', 'S/OFF', 'MDR'}.contains(p['categorie']),
        isTrue,
        reason: 'categorie inattendue: ${p['categorie']}',
      );
    }
  });
}
