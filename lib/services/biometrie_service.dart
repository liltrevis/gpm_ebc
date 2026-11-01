import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Acces a la reconnaissance biometrique de l'appareil
/// (empreinte digitale, reconnaissance faciale, iris, Windows Hello).
class BiometrieService {
  BiometrieService({LocalAuthentication? authentification})
      : _auth = authentification ?? LocalAuthentication();

  final LocalAuthentication _auth;
  String? _derniereErreur;

  /// Message lisible expliquant le dernier echec, ou null.
  String? get derniereErreur => _derniereErreur;

  /// Types biometriques actuellement disponibles sur l'appareil.
  Future<List<BiometricType>> typesDisponibles() async {
    try {
      if (!await _auth.isDeviceSupported()) return const [];
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('BiometrieService.typesDisponibles : $e');
      return const [];
    }
  }

  /// Vrai si l'appareil propose au moins une biometrie enrolee.
  Future<bool> disponible() async => (await typesDisponibles()).isNotEmpty;

  /// Lance la verification biometrique. Retourne true si l'utilisateur est
  /// authentifie, false s'il annule ou si la verification echoue.
  Future<bool> authentifier({
    String raison =
        'Confirmez votre identite pour vous connecter a GPM-2EBC.',
  }) async {
    _derniereErreur = null;
    try {
      return await _auth.authenticate(
        localizedReason: raison,
        // false : autorise aussi le code de deverrouillage de l'appareil en
        // secours, ce qui evite de bloquer l'utilisateur.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      _derniereErreur = _message(e);
      debugPrint('BiometrieService.authentifier : ${e.code.name} ${e.description ?? ''}');
      return false;
    } catch (e) {
      _derniereErreur = 'Reconnaissance indisponible sur cet appareil.';
      debugPrint('BiometrieService.authentifier : $e');
      return false;
    }
  }

  String _message(LocalAuthException e) {
    switch (e.code) {
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'Cet appareil ne dispose pas de lecteur biometrique.';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'Aucune empreinte ou reconnaissance faciale enregistree.';
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
        return 'Reconnaissance annulee.';
      case LocalAuthExceptionCode.timeout:
        return 'Delai de reconnaissance depasse.';
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return 'Lecteur biometrique momentanement indisponible.';
      case LocalAuthExceptionCode.authInProgress:
        return 'Une reconnaissance est deja en cours.';
      default:
        return e.description ?? 'Reconnaissance biometrique impossible.';
    }
  }
}
