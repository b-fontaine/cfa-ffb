import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/backup_bloc.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Export JSON, import avec prévisualisation et confirmation, avertissement
/// quand la persistance est volatile. [fileName] est le nom proposé à
/// l'export (daté, localisé).
class BackupView extends StatelessWidget {
  const BackupView({required this.fileName, super.key});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<BackupBloc, BackupState>(
      builder: (context, state) {
        final bloc = context.read<BackupBloc>();
        final working = state.status == BackupStatus.working;
        final preview = state.preview;
        final failure = state.failure;
        final reasons = state.storageReasons.join(', ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!state.persistent) ...[
              AppAlert(
                level: AlertLevel.persistent,
                message: reasons.isEmpty
                    ? l10n.backupVolatile
                    : '${l10n.backupVolatile} '
                          '${l10n.backupVolatileReasons(reasons)}',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(l10n.backupIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: working
                  ? null
                  : () => bloc.add(
                      BackupEvent.exportRequested(fileName: fileName),
                    ),
              icon: const Icon(Icons.download),
              label: Text(l10n.backupExport),
            ),
            if (state.status == BackupStatus.exported) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.backupExported, style: theme.textTheme.titleSmall),
            ],
            if (state.status == BackupStatus.exportCancelled) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.backupExportCancelled),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: working
                  ? null
                  : () => bloc.add(const BackupEvent.importRequested()),
              icon: const Icon(Icons.upload_file),
              label: Text(l10n.backupImport),
            ),
            if (failure != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                failureMessage(l10n, failure),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (preview != null) ...[
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: l10n.backupPreviewTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in _lines(l10n, preview)) Text(line),
                    if (preview.settings) Text(l10n.backupPreviewSettings),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.backupMergeNote,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton(
                          onPressed: working
                              ? null
                              : () => bloc.add(
                                  const BackupEvent.importConfirmed(),
                                ),
                          child: Text(l10n.backupConfirmImport),
                        ),
                        TextButton(
                          onPressed: () =>
                              bloc.add(const BackupEvent.importCancelled()),
                          child: Text(l10n.commonCancel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (state.status == BackupStatus.imported) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.backupImported, style: theme.textTheme.titleSmall),
            ],
          ],
        );
      },
    );
  }

  List<String> _lines(AppLocalizations l10n, ImportSummary summary) => [
    l10n.backupSeasons(summary.seasons),
    l10n.backupStudents(summary.students),
    l10n.backupGroups(summary.groups),
    l10n.backupSessionRecords(summary.sessionRecords),
    l10n.backupAttempts(summary.attempts),
    l10n.backupAssessments(summary.assessments),
    l10n.backupPlannedSessions(summary.plannedSessions),
    l10n.backupBlockAcquisitions(summary.blockAcquisitions),
  ];
}
