import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Identifiants memorises pour la prochaine connexion.
class IdentifiantsMemorises {
  const IdentifiantsMemorises({
    required this.identifiant,
    required this.motDePasse,
    this.biometrie = false,
  });

  final String identifiant;
  final String motDePasse;

  /// Vrai si l'utilisateur a autorise la connexion par empreinte / visage.
  final bool biometrie;
}

/// Memorise les identifiants dans le stockage securise du systeme :
/// Keystore Android, Keychain iOS/macOS, Credential Manager Windows,
/// libsecret Linux.
///
/// Toutes les erreurs sont absorbees : si le stockage securise n'est pas
/// disponible (par exemple Linux sans libsecret), l'application continue de
/// fonctionner sans memorisation.
class IdentifiantsService {
  static const _cleIdentifiant = 'gpm.identifiant';
  static const _cleMotDePasse = 'gpm.mot_de_passe';
  static const _cleBiometrie = 'gpm.biometrie';

  static const FlutterSecureStorage _stockage = FlutterSecureStorage();

  /// Retourne les identifiants memorises, ou null si aucun.
  Future<IdentifiantsMemorises?> charger() async {
    try {
      final identifiant = await _stockage.read(key: _cleIdentifiant);
      final motDePasse = await _stockage.read(key: _cleMotDePasse);
      if (identifiant == null ||
          identifiant.trim().isEmpty ||
          motDePasse == null ||
          motDePasse.isEmpty) {
        return null;
      }
      final biometrie = await _stockage.read(key: _cleBiometrie);
      return IdentifiantsMemorises(
        identifiant: identifiant,
        motDePasse: motDePasse,
        biometrie: biometrie == '1',
      );
    } catch (e) {
      debugPrint('IdentifiantsService.charger : $e');
      return null;
    }
  }

  /// Enregistre (ou met a jour) les identifiants memorises.
  Future<void> memoriser(
    String identifiant,
    String motDePasse, {
    bool biometrie = false,
  }) async {
    try {
      await _stockage.write(key: _cleIdentifiant, value: identifiant.trim());
      await _stockage.write(key: _cleMotDePasse, value: motDePasse);
      await _stockage.write(key: _cleBiometrie, value: biometrie ? '1' : '0');
    } catch (e) {
      debugPrint('IdentifiantsService.memoriser : $e');
    }
  }

  /// Active ou desactive la connexion biometrique sans changer le mot de passe.
  Future<void> definirBiometrie(bool actif) async {
    try {
      await _stockage.write(key: _cleBiometrie, value: actif ? '1' : '0');
    } catch (e) {
      debugPrint('IdentifiantsService.definirBiometrie : $e');
    }
  }

  /// Oublie totalement les identifiants memorises.
  Future<void> oublier() async {
    try {
      await _stockage.delete(key: _cleIdentifiant);
      await _stockage.delete(key: _cleMotDePasse);
      await _stockage.delete(key: _cleBiometrie);
    } catch (e) {
      debugPrint('IdentifiantsService.oublier : $e');
    }
  }
}
