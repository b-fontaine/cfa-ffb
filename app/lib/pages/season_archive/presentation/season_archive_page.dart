import 'package:billard_cfa/features/track_seasons/presentation/ui/season_archive_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';

/// « Saisons passées » : les archives des saisons closes (bloc fourni par
/// l'appelant). [onBack] ramène à la destination « Plus ».
class SeasonArchivePage extends StatelessWidget {
  const SeasonArchivePage({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScrollPage(
      title: l10n.seasonsTitle,
      subtitle: l10n.seasonsSubtitle,
      onBack: onBack,
      backLabel: l10n.backupBackToMore,
      children: const [SeasonArchiveView()],
    );
  }
}
