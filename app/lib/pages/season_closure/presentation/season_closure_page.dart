import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_bloc.dart';
import 'package:billard_cfa/features/close_season/presentation/bloc/season_closure_bloc.dart';
import 'package:billard_cfa/features/close_season/presentation/ui/season_closure_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// L'assistant de clôture d'une saison, hors du cadre de navigation pour
/// qu'un geste ne le quitte pas à mi-chemin. La page compose l'assistant
/// (feature `close_season`) et l'export de sauvegarde (feature `backup_data`),
/// qu'une feature n'importerait pas. Les blocs sont fournis par l'appelant.
class SeasonClosurePage extends StatelessWidget {
  const SeasonClosurePage({
    required this.today,
    required this.onCancel,
    required this.onSeasons,
    required this.onHome,
    super.key,
  });

  final DateTime today;
  final VoidCallback onCancel;
  final VoidCallback onSeasons;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final label = context.select<SeasonClosureBloc, String>(
      (bloc) => bloc.state.plan?.season.label ?? '',
    );
    return BlocListener<SeasonClosureBloc, SeasonClosureState>(
      // L'export d'après clôture repart d'un état neuf : « Sauvegarde faite »
      // ne doit pas venir de l'export d'avant.
      listenWhen: (previous, current) =>
          current.status == SeasonClosureStatus.closed &&
          previous.status != SeasonClosureStatus.closed,
      listener: (context, _) =>
          context.read<BackupBloc>().add(const BackupEvent.started()),
      child: ScrollPage(
        title: label.isEmpty ? l10n.closureCancel : l10n.closureTitle(label),
        onBack: onCancel,
        backLabel: l10n.closureCancel,
        children: [
          SeasonClosureView(
            backupSection: _Export(fileName: l10n.backupFileName(date)),
            backupAfterSection: _Export(fileName: l10n.backupFileName(date)),
            onSeasons: onSeasons,
            onHome: onHome,
          ),
        ],
      ),
    );
  }
}

/// Bouton d'export de sauvegarde et son état (« Sauvegarde faite. »).
class _Export extends StatelessWidget {
  const _Export({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<BackupBloc, BackupState>(
      builder: (context, state) {
        final working = state.status == BackupStatus.working;
        final failure = state.failure;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: working
                  ? null
                  : () => context.read<BackupBloc>().add(
                      BackupEvent.exportRequested(fileName: fileName),
                    ),
              icon: const Icon(Icons.download),
              label: Text(l10n.closureBackupAction),
            ),
            if (state.status == BackupStatus.exported) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.closureBackupDone,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
            if (state.status == BackupStatus.exportCancelled) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.backupExportCancelled),
            ],
            if (failure != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                failureMessage(l10n, failure),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        );
      },
    );
  }
}
