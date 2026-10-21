import 'package:billard_cfa/features/backup_data/presentation/ui/local_export_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';

/// « Exporter mes données locales » (bloc fourni par l'appelant) : hors du
/// cadre de navigation, car l'écran s'ouvre aussi **sans compte** (écran de
/// connexion). [today] date le nom du fichier ; [onBack] revient à l'écran qui
/// l'a ouvert.
class LocalExportPage extends StatelessWidget {
  const LocalExportPage({required this.today, required this.onBack, super.key});

  final DateTime today;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    return ScrollPage(
      title: l10n.localExportTitle,
      onBack: onBack,
      backLabel: l10n.localExportBack,
      children: [LocalExportView(fileName: l10n.localExportFileName(date))],
    );
  }
}
