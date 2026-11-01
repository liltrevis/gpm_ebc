/// Utilitaires de formatage de dates.
String formatDateFr(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final j = d.day.toString().padLeft(2, '0');
  final m = d.month.toString().padLeft(2, '0');
  return '$j/$m/${d.year}';
}

String formatDateHeureFr(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final h = d.hour.toString().padLeft(2, '0');
  final mn = d.minute.toString().padLeft(2, '0');
  return '${formatDateFr(iso)} $h:$mn';
}

String aujourdHui() {
  final d = DateTime.now();
  final m = d.month.toString().padLeft(2, '0');
  final j = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$j';
}

String afficherDateFr(String? yyyymmdd) {
  if (yyyymmdd == null || yyyymmdd.isEmpty) return '-';
  final parts = yyyymmdd.split('-');
  if (parts.length != 3) return yyyymmdd;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}
