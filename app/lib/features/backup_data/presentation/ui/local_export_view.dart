import 'package:billard_cfa/features/backup_data/domain/import_summary.dart';
import 'package:billard_cfa/features/backup_data/presentation/bloc/local_export_cubit.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Export de la base locale (FB7c) : montre ce que contiendra le fichier
/// **avant** de l'enregistrer, et ne propose jamais d'enregistrer un fichier
/// vide. [fileName] est le nom proposé (daté, localisé).
class LocalExportView extends StatelessWidget {
  const LocalExportView({required this.fileName, super.key});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<LocalExportCubit, LocalExportState>(
      builder: (context, state) {
        final cubit = context.read<LocalExportCubit>();
        final summary = state.summary;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.localExportIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.localExportPrivacy, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            switch (state.status) {
              LocalExportStatus.loading => Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(l10n.localExportReading)),
                  ],
                ),
              ),
              LocalExportStatus.newerSchema => Semantics(
                liveRegion: true,
                child: AppAlert(
                  level: AlertLevel.persistent,
                  message: l10n.localExportNewer,
                ),
              ),
              LocalExportStatus.unreadable => _Failure(
                message: l10n.localExportUnreadable,
                onRetry: cubit.prepare,
              ),
              LocalExportStatus.saveFailed => _Failure(
                message: l10n.localExportSaveFailed,
                onRetry: cubit.prepare,
              ),
              LocalExportStatus.ready ||
              LocalExportStatus.saved ||
              LocalExportStatus.cancelled => _Ready(
                state: state,
                summary: summary!,
                onSave: () => cubit.save(fileName: fileName),
                onRetry: cubit.prepare,
              ),
            },
          ],
        );
      },
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        liveRegion: true,
        child: AppAlert(level: AlertLevel.persistent, message: message),
      ),
      const SizedBox(height: AppSpacing.md),
      OutlinedButton(
        onPressed: onRetry,
        child: Text(AppLocalizations.of(context).localExportRetry),
      ),
    ],
  );
}

class _Ready extends StatelessWidget {
  const _Ready({
    required this.state,
    required this.summary,
    required this.onSave,
    required this.onRetry,
  });

  final LocalExportState state;
  final ImportSummary summary;
  final VoidCallback onSave;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final saved = state.status == LocalExportStatus.saved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: l10n.localExportContentsTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in _lines(l10n, summary)) Text(line),
              if (state.migrated) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.localExportMigrated),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.empty) ...[
          Semantics(
            liveRegion: true,
            child: AppAlert(
              level: AlertLevel.attention,
              message: l10n.localExportEmpty,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(l10n.localExportRetry),
          ),
        ] else ...[
          if (!saved)
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.download),
              label: Text(l10n.localExportSave),
            ),
          if (saved)
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.localExportSaved(
                  l10n.backupStudents(summary.students),
                  l10n.backupAttempts(summary.attempts),
                ),
                style: theme.textTheme.titleSmall,
              ),
            ),
          if (state.status == LocalExportStatus.cancelled) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(liveRegion: true, child: Text(l10n.localExportCancelled)),
          ],
        ],
      ],
    );
  }

  List<String> _lines(AppLocalizations l10n, ImportSummary s) => [
    l10n.backupStudents(s.students),
    l10n.backupGroups(s.groups),
    l10n.backupSessionRecords(s.sessionRecords),
    l10n.backupAttempts(s.attempts),
    l10n.backupPlannedSessions(s.plannedSessions),
    l10n.backupAssessments(s.assessments),
    l10n.backupBlockAcquisitions(s.blockAcquisitions),
    l10n.backupSeasons(s.seasons),
    if (s.seasonArchives > 0) l10n.backupSeasonArchives(s.seasonArchives),
  ];
}
