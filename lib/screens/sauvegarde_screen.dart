import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_reload.dart';
import '../services/sauvegarde_service.dart';

/// Ecran de sauvegarde / restauration de la base (echange entre appareils).
class SauvegardeScreen extends StatefulWidget {
  const SauvegardeScreen({super.key});

  @override
  State<SauvegardeScreen> createState() => _SauvegardeScreenState();
}

class _SauvegardeScreenState extends State<SauvegardeScreen> {
  bool _occupe = false;

  void _message(String texte, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texte),
        backgroundColor: erreur ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _exporter() async {
    setState(() => _occupe = true);
    try {
      final fichier = await SauvegardeService.preparerCopie();
      final nomFichier = p.basename(fichier.path);
      if (Platform.isAndroid || Platform.isIOS) {
        // Sur mobile : feuille de partage (Drive, WhatsApp, e-mail...).
        await SharePlus.instance.share(ShareParams(
          files: [XFile(fichier.path, mimeType: 'application/octet-stream')],
          subject: 'Sauvegarde GPM-2EBC',
          text: 'Sauvegarde de la base GPM-2EBC ($nomFichier)',
        ));
      } else {
        // Sur ordinateur : dialogue "Enregistrer sous".
        final uri = await FilePicker.saveFile(
          dialogTitle: 'Enregistrer la sauvegarde',
          fileName: nomFichier,
          bytes: await fichier.readAsBytes(),
          mimeType: 'application/octet-stream',
        );
        if (uri != null) _message('Sauvegarde enregistrée.');
      }
    } catch (e) {
      _message('Echec de l\'export : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _importer() async {
    final choix = await FilePicker.pickFile(
      dialogTitle: 'Choisir une sauvegarde GPM-2EBC (.db)',
      type: FileType.any,
    );
    if (choix == null) return;

    final confirme = await _confirmerImport();
    if (confirme != true) return;

    setState(() => _occupe = true);
    try {
      File fichier;
      if (choix.path != null) {
        fichier = File(choix.path!);
      } else {
        final dir = await getTemporaryDirectory();
        fichier = File(p.join(dir.path,
            'import_${DateTime.now().millisecondsSinceEpoch}.db'));
        await fichier.writeAsBytes(await choix.readAsBytes());
      }
      await SauvegardeService.importer(fichier);
      if (!mounted) return;
      await _annoncerRedemarrage();
      rechargerApplication();
    } on SauvegardeException catch (e) {
      _message(e.message, erreur: true);
    } catch (e) {
      _message('Échec de l\'import : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<bool?> _confirmerImport() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remplacer les données ?'),
        content: const Text(
          'Les données actuelles de cet appareil seront remplacées par '
          'celles de la sauvegarde choisie.\n\n'
          'Une copie de sécurité de la base actuelle est conservée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remplacer'),
          ),
        ],
      ),
    );
  }

  Future<void> _annoncerRedemarrage() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Import réussi'),
        content: const Text(
            'La sauvegarde a été restaurée. L\'application va se recharger.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde et échange')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Base de données locale',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        'L\'application fonctionne hors-ligne : chaque appareil '
                        'possède sa propre base. Pour partager les données entre '
                        'appareils, exportez la base depuis un appareil puis '
                        'importez-la sur les autres.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Exporter la base'),
                  subtitle: const Text(
                      'Enregistrer ou partager une sauvegarde (.db)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _occupe ? null : _exporter,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined),
                  title: const Text('Importer une base'),
                  subtitle: const Text(
                      'Restaurer une sauvegarde (remplace les données locales)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _occupe ? null : _importer,
                ),
              ),
            ],
          ),
          if (_occupe)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
