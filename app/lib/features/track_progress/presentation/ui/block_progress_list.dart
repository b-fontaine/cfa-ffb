import 'package:billard_cfa/features/track_progress/domain/block_progress.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/progress_meter.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Progression de l'élève bloc par bloc, dans l'ordre d'enseignement : taux
/// d'exercices validés, statut (icône + libellé), séances passées.
class BlockProgressList extends StatelessWidget {
  const BlockProgressList({required this.sheet, super.key});

  final StudentSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SectionCard(
      title: l10n.sheetBlocks,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final progress in sheet.report.blocks)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sheet.catalogue.blockById(progress.blockId)!.title,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      _statusBadge(l10n, progress.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ProgressMeter(
                    value: progress.validatedCount,
                    maximum: progress.exerciseCount,
                    label: l10n.sheetBlockRate(progress.percentValidated),
                  ),
                  Text(
                    l10n.sheetBlockExercises(
                      progress.validatedCount,
                      progress.exerciseCount,
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    l10n.sheetBlockSessions(progress.sessionsSpent),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (progress.overdue)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: StatusBadge(
                        tone: BadgeTone.attention,
                        label: l10n.sheetBlockOverdue,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(AppLocalizations l10n, BlockStatus status) =>
      switch (status) {
        BlockStatus.mastered => StatusBadge(
          tone: BadgeTone.success,
          label: l10n.statusMastered,
        ),
        BlockStatus.toReview => StatusBadge(
          tone: BadgeTone.attention,
          label: l10n.statusToReview,
        ),
        BlockStatus.inProgress => StatusBadge(
          tone: BadgeTone.neutral,
          label: l10n.statusInProgress,
        ),
        BlockStatus.notStarted => StatusBadge(
          tone: BadgeTone.neutral,
          label: l10n.statusNotStarted,
        ),
      };
}
