/// Constantes globales de l'application GPM-2EBC.
class AppUnit {
  static const String libelle = "2e ESCADRON BLINDE DE COMBAT";
  static const String libelleLong = "SITUATION DE PRISE D'ARMES - 2e ESCADRON BLINDE DE COMBAT";
  static const String localisation = "Akouedo";
}

/// Ressources graphiques (assets).
class AppImages {
  static const String logo = 'assets/images/logo.png';
}

/// Codes de statut (situation administrative).
class StatutCode {
  static const String enService = 'EN_SERVICE';
  static const String enMission = 'EN_MISSION';
  static const String enStage = 'EN_STAGE';
  static const String miseADisposition = 'MISE_A_DISPOSITION';
  static const String enPermission = 'EN_PERMISSION';
  static const String enConge = 'EN_CONGE';
  static const String malade = 'MALADE';
  static const String reposMedical = 'REPOS_MEDICAL';
  static const String absent = 'ABSENT';
  static const String radie = 'RADIE';
  static const String decede = 'DECEDE';
}

/// Codes de type d'usage d'arme.
class TypeUsage {
  static const String garde = 'GARDE';
  static const String instruction = 'INSTRUCTION';
  static const String operation = 'OPERATION';
}

/// Codes de motif de mouvement d'armurerie.
class MotifMouvement {
  static const String garde = 'GARDE';
  static const String instruction = 'INSTRUCTION';
  static const String tir = 'TIR';
  static const String operation = 'OPERATION';
  static const String inventaire = 'INVENTAIRE';
}

/// Libelles de grade (ordre hierarchique croissant).
const Map<String, String> kGrades = {
  // Officiers
  'SLT': 'Sous-Lieutenant',
  'LTN': 'Lieutenant',
  'CNE': 'Capitaine',
  'CDT': 'Commandant',
  'LCL': 'Lieutenant-Colonel',
  'COL': 'Colonel',
  'COLM': 'Colonel major',
  // Sous-officiers
  'MDL': 'Marechal des Logis',
  'MDC': 'Marechal des Logis Chef',
  'ADT': 'Adjudant',
  'ADC': 'Adjudant-chef',
  'ACM': 'Adjudant-chef major',
  // Militaires du rang
  'CLIER2': 'Cavalier de 2e classe',
  'CLIER1': 'Cavalier de 1ere classe',
  'BIER': 'Brigadier',
  'BCH': 'Brigadier-chef',
};

const Map<String, int> kGradeOrdre = {
  'SLT': 10,
  'LTN': 20,
  'CNE': 30,
  'CDT': 40,
  'LCL': 50,
  'COL': 60,
  'COLM': 70,
  'MDL': 110,
  'MDC': 120,
  'ADT': 130,
  'ADC': 140,
  'ACM': 150,
  'CLIER2': 210,
  'CLIER1': 220,
  'BIER': 230,
  'BCH': 240,
};

const Map<String, String> kCategories = {
  'OFF': 'Officier',
  'S-OFF': 'Sous-officier',
  'MDR': 'Militaire du rang',
};

/// Categorie statutaire (code) deduite de l'ordre du grade.
String categorieDepuisOrdre(int ordre) {
  if (ordre < 100) return 'OFF';
  if (ordre < 200) return 'S-OFF';
  return 'MDR';
}

/// Categorie statutaire (code) deduite du code grade (null si inconnu).
String? categorieDepuisGrade(String? gradeCode) {
  final ordre = kGradeOrdre[(gradeCode ?? '').trim().toUpperCase()];
  return ordre == null ? null : categorieDepuisOrdre(ordre);
}
