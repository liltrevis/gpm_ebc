// Donnees de reference et jeu de donnees initial, extraits du fichier
// principal BASE DE DONNEES 2eEBC.xlsx (feuille Sheet1).

export 'seed_personnel.dart';

const List<List<String>> kSections = [
  ['EM', 'Peloton Cmd', '0'],
  ['S1', '1er Peloton', '1'],
  ['S2', '2e Peloton', '2'],
  ['S3', '3e Peloton', '3'],
  ['4E_PELOTON', '4e Peloton', '4'],
];

const List<List<String>> kFonctions = [
  ['CMD_UNITE', 'Commandant d\'unite'],
  ['CMD_SECTION', 'Chef de peloton'],
  ['CHEF_GROUPE', 'Chef de groupe'],
  ['CHEF_EQUIPE', 'Chef d\'equipe'],
  ['ARMURIER', 'Armurier'],
  ['SECRETAIRE_RH', 'Secretaire RH'],
  ['MILITAIRE', 'Militaire'],
];

/// [code, libelle, libelleRapport, disponible, ordreRapport]
const List<List<String>> kStatuts = [
  ['EN_SERVICE', 'Présent', 'Presents', '1', '0'],
  ['EN_MISSION', 'En mission', 'Mission', '0', '1'],
  ['EN_STAGE', 'En stage', 'Stage', '0', '2'],
  ['MISE_A_DISPOSITION', 'Mise a disposition', 'Mise a disposition', '0', '3'],
  ['EN_PERMISSION', 'En permission', 'Permission', '0', '4'],
  ['EN_CONGE', 'En conge', 'Permission', '0', '5'],
  ['MALADE', 'Malade', 'Malades', '0', '6'],
  ['REPOS_MEDICAL', 'Repos medical', 'Repos medical', '0', '7'],
  ['ABSENT', 'Absent', 'Absent', '0', '8'],
  ['RADIE', 'Radie', 'Indisponible', '0', '9'],
  ['DECEDE', 'Decede', 'Indisponible', '0', '10'],
];

/// [code, libelle, calibre]
const List<List<String>> kTypesArme = [
  ['AK47', 'Fusil d\'assaut AK-47', '7,62 mm'],
  ['T80', 'Mitrailleuse T80', '7,62 mm'],
  ['MIT12_7', 'Mitrailleuse lourde', '12,7 mm'],
  ['PM', 'Pistolet mitrailleur', '9 mm'],
];

/// [numeroSerie, typeCode, marque, etat]
const List<List<String>> kArmes = [
  ['AK47-000101', 'AK47', 'Kalachnikov', 'EN_SERVICE'],
  ['AK47-000102', 'AK47', 'Kalachnikov', 'EN_SERVICE'],
  ['AK47-000103', 'AK47', 'Kalachnikov', 'EN_SERVICE'],
  ['AK47-000104', 'AK47', 'Kalachnikov', 'EN_SERVICE'],
  ['AK47-000105', 'AK47', 'Kalachnikov', 'EN_SERVICE'],
  ['AK47-000106', 'AK47', 'Kalachnikov', 'REPARATION'],
  ['T80-002001', 'T80', 'Pecheneg', 'EN_SERVICE'],
  ['T80-002002', 'T80', 'Pecheneg', 'EN_SERVICE'],
  ['MIT12_7-003001', 'MIT12_7', 'DSHK', 'EN_SERVICE'],
  ['MIT12_7-003002', 'MIT12_7', 'DSHK', 'REFORMEE'],
  ['PM-004001', 'PM', 'Beretta', 'EN_SERVICE'],
  ['PM-004002', 'PM', 'Beretta', 'EN_SERVICE'],
];

/// [typeCalibre, designation, stock, seuil, unite]
const List<List<String>> kMunitions = [
  ['7,62 mm', 'Cartouches 7,62x39', '1200', '400', 'cartouches'],
  ['7,62 mm', 'Cartouches 7,62x54R', '800', '300', 'cartouches'],
  ['12,7 mm', 'Cartouches 12,7x108', '150', '100', 'cartouches'],
  ['9 mm', 'Cartouches 9x19', '600', '200', 'cartouches'],
];

/// Postes de service [code, libelle].
const List<List<String>> kPostes = [
  ['PP', 'Porte principale'],
  ['PG', 'Poste de garde'],
  ['MAG', 'Magasin'],
  ['PC', 'Poste de commandement'],
  ['ARM', 'Armurerie'],
];

/// Utilisateurs de demonstration [username, nomComplet, motDePasse, roleCode,
/// codeSection]. Le peloton (section) ne concerne que les Chefs de Peloton.
const List<List<String>> kUsers = [
  ['admin', 'MDC KOUKOUGNON GBEYERE', 'admin123', 'CMD_ESC', ''],
  ['cmd', 'CNE KOFFI KPANGNI OSKINS PRIVAT', 'cmd123', 'CMD_ESC', ''],
  ['rh', 'SLT ALLECHI KAUDJIS', 'rh123', 'CMD_ESC', ''],
  ['armurier', 'LTN MAMBO GUY LEROY', 'arm123', 'CHEF_PEL', 'S2'],
  ['section', 'LTN DOSSOU PIERRE', 'sec123', 'CHEF_PEL', 'S1'],
];
