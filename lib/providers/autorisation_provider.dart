import 'package:flutter/foundation.dart';

import '../data/autorisation_repository.dart';
import '../models/app_user.dart';

/// Autorisations de modification accordees par le Commandant Escadron aux
/// chefs de peloton (visibles et gerables depuis l'onglet "Plus").
class AutorisationProvider extends ChangeNotifier {
  final AutorisationRepository _repo;
  AutorisationProvider(this._repo);

  /// section_id -> code -> accorde.
  final Map<int, Map<String, bool>> _accords = {};
  bool loading = false;

  Future<void> charger() async {
    loading = true;
    notifyListeners();
    try {
      final data = await _repo.toutes();
      _accords
        ..clear()
        ..addAll(data);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Vrai si l'autorisation [code] est accordee au peloton [sectionId].
  bool estAccordee(int? sectionId, String code) {
    if (sectionId == null) return false;
    return _accords[sectionId]?[code] ?? false;
  }

  /// Vrai si [user] peut modifier ce domaine : le Commandant Escadron n'est
  /// pas restreint, le Chef de Peloton doit y avoir ete autorise.
  bool autorisePour(AppUser? user, String code) {
    if (user == null) return false;
    if (!user.estChefPeloton) return true;
    return estAccordee(user.perimetreSectionId, code);
  }

  Future<void> definir({
    required int sectionId,
    required String code,
    required bool accorde,
    AppUser? acteur,
  }) async {
    await _repo.definir(
      sectionId: sectionId,
      code: code,
      accorde: accorde,
      utilisateurId: acteur?.id,
      utilisateurNom: acteur?.nomComplet,
    );
    (_accords[sectionId] ??= {})[code] = accorde;
    notifyListeners();
  }
}
