import 'package:flutter/material.dart';

import '../core/constants.dart';

/// Logo de l'escadron (asset bundle). Affiche une icone de secours si l'image
/// n'est pas disponible.
class EscadronLogo extends StatelessWidget {
  const EscadronLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppImages.logo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.shield_moon, size: size),
    );
  }
}
