import 'package:billard_cfa/features/backup_data/presentation/bloc/club_import_cubit.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_actions.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/club_import_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:flutter/material.dart';

/// « Importer dans le club » (FB7, partie B) : le parcours d'import d'une
/// sauvegarde de l'ancienne version, sous « Plus ». L'état et les commandes
/// viennent du cubit, branché par le routeur ; [onBack] ramène à « Plus ».
class ClubImportPage extends StatelessWidget {
  const ClubImportPage({
    required this.state,
    required this.actions,
    required this.onBack,
    super.key,
  });

  final ClubImportState state;
  final ClubImportActions actions;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScrollPage(
      title: l10n.clubImportTitle,
      onBack: onBack,
      backLabel: l10n.backupBackToMore,
      children: [ClubImportView(state: state, actions: actions)],
    );
  }
}
