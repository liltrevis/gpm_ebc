import 'package:flutter/material.dart';

import '../core/colonnes_etat.dart';

/// Boite de dialogue de selection des colonnes a inclure dans l'export d'un
/// etat. Retourne les colonnes cochees (dans l'ordre de [kColonnesEtat]) ou
/// `null` si l'utilisateur annule.
Future<List<ColonneEtat>?> choisirColonnesEtat(
  BuildContext context, {
  Iterable<String>? preselection,
}) {
  final selection = <String>{
    if (preselection != null) ...preselection else ...colonnesParDefaut().map((c) => c.cle),
  };
  return showDialog<List<ColonneEtat>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Informations a exporter'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in kColonnesEtat)
                CheckboxListTile(
                  value: selection.contains(c.cle),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(c.libelle),
                  onChanged: (v) => setLocal(() {
                    if (v == true) {
                      selection.add(c.cle);
                    } else {
                      selection.remove(c.cle);
                    }
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: selection.isEmpty
                ? null
                : () => Navigator.of(ctx).pop(
                      kColonnesEtat
                          .where((c) => selection.contains(c.cle))
                          .toList(),
                    ),
            child: const Text('Exporter'),
          ),
        ],
      ),
    ),
  );
}
