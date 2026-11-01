import 'package:flutter/foundation.dart';

import '../data/utilisateur_repository.dart';
import '../models/app_user.dart';

/// Etat d'authentification et de session.
class AuthProvider extends ChangeNotifier {
  final UtilisateurRepository _repo;
  AuthProvider(this._repo);

  AppUser? _user;
  bool _loading = false;
  String? _erreur;

  AppUser? get user => _user;
  bool get connecte => _user != null;
  bool get loading => _loading;
  String? get erreur => _erreur;

  bool get estChefPeloton => _user?.estChefPeloton ?? false;

  /// Peloton auquel l'utilisateur est restreint (Chef de Peloton), sinon null.
  int? get perimetreSectionId => _user?.perimetreSectionId;

  Future<bool> connexion(String username, String motDePasse) async {
    _loading = true;
    _erreur = null;
    notifyListeners();
    try {
      final u = await _repo.authentifier(username, motDePasse);
      if (u == null) {
        _erreur = 'Identifiants incorrects.';
        _user = null;
      } else {
        _user = u;
      }
    } catch (e) {
      _erreur = 'Erreur de connexion: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
    return _user != null;
  }

  void deconnexion() {
    _user = null;
    notifyListeners();
  }

  bool peut(String permission) => _user?.hasPermission(permission) ?? false;
}
