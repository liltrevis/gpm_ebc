import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/biometrie_service.dart';
import '../services/identifiants_service.dart';
import '../widgets/escadron_logo.dart';

/// Ecran de connexion.
///
/// - Champs vides par defaut sur une installation neuve.
/// - Option « Se souvenir de moi » : identifiants conserves dans le stockage
///   securise du systeme et pre-remplis a la prochaine ouverture.
/// - Connexion par empreinte digitale / reconnaissance faciale (ou Windows
///   Hello) lorsque l'appareil le permet.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Evite de relancer automatiquement la biometrie apres une deconnexion :
  /// seule la premiere ouverture de l'application la propose.
  static bool _biometrieProposee = false;

  final _formKey = GlobalKey<FormState>();
  final _identifiant = TextEditingController();
  final _motDePasse = TextEditingController();
  final _identifiantsService = IdentifiantsService();
  final _biometrieService = BiometrieService();

  bool _obscur = true;
  bool _memoriser = false;
  bool _biometrie = false;
  bool _biometrieEnCours = false;
  bool _initialisation = true;
  List<BiometricType> _typesBiometrie = const <BiometricType>[];
  IdentifiantsMemorises? _identifiantsMemorises;

  bool get _biometrieDisponible => _typesBiometrie.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    final types = await _biometrieService.typesDisponibles();
    final memorises = await _identifiantsService.charger();
    if (!mounted) return;
    setState(() {
      _typesBiometrie = types;
      _identifiantsMemorises = memorises;
      if (memorises != null) {
        _identifiant.text = memorises.identifiant;
        _motDePasse.text = memorises.motDePasse;
        _memoriser = true;
        _biometrie = memorises.biometrie && types.isNotEmpty;
      }
      _initialisation = false;
    });

    // Propose la reconnaissance des l'ouverture si elle a ete activee.
    if (!_biometrieProposee &&
        memorises != null &&
        memorises.biometrie &&
        types.isNotEmpty) {
      _biometrieProposee = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _connexionBiometrique();
      });
    }
  }

  @override
  void dispose() {
    _identifiant.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate()) return;
    // Capture avant l'attente : l'ecran peut etre remplace par l'accueil des
    // que la connexion reussit (les controleurs seraient alors liberes).
    final identifiant = _identifiant.text.trim();
    final motDePasse = _motDePasse.text;
    final memoriser = _memoriser;
    final biometrie = _biometrie && _biometrieDisponible;
    final auth = context.read<AuthProvider>();
    final ok = await auth.connexion(identifiant, motDePasse);
    if (!mounted) return;
    if (!ok) {
      if (auth.erreur != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(auth.erreur!)));
      }
      return;
    }
    // Connexion reussie : met a jour la memorisation.
    if (memoriser) {
      await _identifiantsService.memoriser(
        identifiant,
        motDePasse,
        biometrie: biometrie,
      );
    } else {
      await _identifiantsService.oublier();
    }
  }

  Future<void> _connexionBiometrique() async {
    if (_biometrieEnCours) return;
    final memorises = _identifiantsMemorises;
    if (memorises == null) {
      _message('Aucun identifiant memorise : connectez-vous une premiere fois.');
      return;
    }
    setState(() => _biometrieEnCours = true);
    final ok = await _biometrieService.authentifier(
      raison: 'Connexion a GPM-2EBC par $_libelleBiometrie',
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _biometrieEnCours = false);
      final erreur = _biometrieService.derniereErreur;
      if (erreur != null && erreur != 'Reconnaissance annulee.') {
        _message(erreur);
      }
      return;
    }
    final auth = context.read<AuthProvider>();
    final reussi =
        await auth.connexion(memorises.identifiant, memorises.motDePasse);
    if (!mounted) return;
    setState(() => _biometrieEnCours = false);
    if (!reussi) {
      _message(auth.erreur ??
          'Identifiants memorises invalides. Reconnectez-vous manuellement.');
    }
  }

  Future<void> _basculerBiometrie(bool valeur) async {
    if (!valeur) {
      setState(() => _biometrie = false);
      return;
    }
    if (!_memoriser) {
      setState(() => _memoriser = true);
    }
    setState(() => _biometrieEnCours = true);
    final ok = await _biometrieService.authentifier(
      raison: 'Activez la connexion a GPM-2EBC par $_libelleBiometrie',
    );
    if (!mounted) return;
    setState(() {
      _biometrieEnCours = false;
      _biometrie = ok;
    });
    if (!ok) {
      final erreur = _biometrieService.derniereErreur;
      if (erreur != null && erreur != 'Reconnaissance annulee.') {
        _message(erreur);
      }
    }
  }

  void _message(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texte)));
  }

  String get _libelleBiometrie {
    final empreinte = _typesBiometrie.contains(BiometricType.fingerprint);
    final visage = _typesBiometrie.contains(BiometricType.face);
    final iris = _typesBiometrie.contains(BiometricType.iris);
    if (empreinte && visage) return 'empreinte ou visage';
    if (empreinte) return 'empreinte digitale';
    if (visage) return 'reconnaissance faciale';
    if (iris) return 'iris';
    return 'biometrie de l\'appareil';
  }

  IconData get _iconeBiometrie {
    if (_typesBiometrie.contains(BiometricType.face) &&
        !_typesBiometrie.contains(BiometricType.fingerprint)) {
      return Icons.face;
    }
    return Icons.fingerprint;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final peutUtiliserBiometrie =
        _biometrieDisponible && _identifiantsMemorises != null && _biometrie;
    final occupe = auth.loading || _biometrieEnCours || _initialisation;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const EscadronLogo(size: 96),
                      const SizedBox(height: 12),
                      Text(
                        AppUnit.libelle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gestion du personnel',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _identifiant,
                        readOnly: _biometrieEnCours,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Identifiant',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Identifiant requis'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _motDePasse,
                        readOnly: _biometrieEnCours,
                        obscureText: _obscur,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscur
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setState(() => _obscur = !_obscur),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Mot de passe requis'
                            : null,
                        onFieldSubmitted: (_) => _valider(),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _memoriser,
                        onChanged: occupe
                            ? null
                            : (v) => setState(() {
                                  _memoriser = v ?? false;
                                  if (!_memoriser) _biometrie = false;
                                }),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Se souvenir de mes identifiants'),
                        subtitle: const Text(
                          'Conserves de facon securisee sur cet appareil',
                        ),
                      ),
                      if (_biometrieDisponible)
                        CheckboxListTile(
                          value: _biometrie,
                          onChanged: occupe
                              ? null
                              : (v) => _basculerBiometrie(v ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          secondary: Icon(_iconeBiometrie),
                          title: const Text('Connexion par empreinte ou visage'),
                          subtitle: Text(
                            'Disponible : $_libelleBiometrie',
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (peutUtiliserBiometrie) ...[
                        OutlinedButton.icon(
                          onPressed: occupe ? null : _connexionBiometrique,
                          icon: _biometrieEnCours
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(_iconeBiometrie),
                          label: Text('Se connecter par $_libelleBiometrie'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      FilledButton.icon(
                        onPressed: occupe ? null : _valider,
                        icon: auth.loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Se connecter'),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      Text(
                        'Comptes de demonstration :\n'
                        'Commandant Escadron : admin/admin123  -  cmd/cmd123\n'
                        'Chef de Peloton : section/sec123 (1er Pel.)  -  armurier/arm123 (2e Pel.)',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
