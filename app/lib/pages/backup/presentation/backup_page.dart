import 'package:billard_cfa/features/backup_data/presentation/ui/backup_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';

/// Sauvegarde et restauration des données du club (bloc fourni par
/// l'appelant). [today] date le nom du fichier exporté.
class BackupPage extends StatelessWidget {
  const BackupPage({required this.today, super.key});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    return ScrollPage(
      title: l10n.backupTitle,
      children: [BackupView(fileName: l10n.backupFileName(date))],
    );
  }
}
