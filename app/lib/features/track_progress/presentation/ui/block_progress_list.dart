import 'package:billard_cfa/features/track_progress/domain/block_progress.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/progress_meter.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Progression de l'élève bloc par bloc, dans l'ordre d'enseignement : taux
/// d'exercices validés, statut (icône + libellé), séances passées.
///
/// [onMarkAcquired] et [onRevokeAcquired] reçoivent l'identifiant du bloc
/// (positionnement, ADR 0008) ; ils sont fournis par la page, qui compose la
/// fonctionnalité de positionnement. Sans eux, aucune action n'est proposée.
class BlockProgressList extends StatelessWidget {
  const BlockProgressList({
    required this.sheet,
    this.onMarkAcquired,
    this.onRevokeAcquired,
    super.key,
  });

  final StudentSheet sheet;
  final ValueChanged<String>? onMarkAcquired;
  final ValueChanged<String>? onRevokeAcquired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sheet.catalogue
                                  .blockById(progress.blockId)!
                                  .title,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (sheet.catalogue
                                .blockById(progress.blockId)!
                                .isProposal) ...[
                              const SizedBox(height: AppSpacing.xs),
                              const ProposalBadge(),
                            ],
                          ],
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
                  if (progress.acquiredOn != null)
                    Text(
                      progress.resumedCount == 0
                          ? l10n.placementOn(
                              dates.formatMediumDate(progress.acquiredOn!),
                            )
                          : l10n.placementResumed(
                              dates.formatMediumDate(progress.acquiredOn!),
                              progress.resumedCount,
                            ),
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
                  ..._placementActions(l10n, progress),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// « Retirer l'acquis » dès qu'un marqueur existe ; « Marquer le bloc
  /// acquis » sinon, sauf pour un bloc déjà acquis par passages.
  List<Widget> _placementActions(
    AppLocalizations l10n,
    BlockProgress progress,
  ) {
    final onRevoke = onRevokeAcquired;
    final onMark = onMarkAcquired;
    if (progress.acquiredOn != null) {
      if (onRevoke == null) return const [];
      return [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => onRevoke(progress.blockId),
            child: Text(l10n.placementRevokeAction),
          ),
        ),
      ];
    }
    if (onMark == null || progress.status == BlockStatus.mastered) {
      return const [];
    }
    final title = sheet.catalogue.blockById(progress.blockId)!.title;
    return [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          button: true,
          label: l10n.placementMarkActionFor(title),
          excludeSemantics: true,
          child: TextButton(
            onPressed: () => onMark(progress.blockId),
            child: Text(l10n.placementMarkAction),
          ),
        ),
      ),
    ];
  }

  Widget _statusBadge(AppLocalizations l10n, BlockStatus status) =>
      switch (status) {
        BlockStatus.mastered => StatusBadge(
          tone: BadgeTone.success,
          label: l10n.statusMastered,
        ),
        BlockStatus.acquiredAtPlacement => StatusBadge(
          tone: BadgeTone.success,
          label: l10n.statusAcquiredAtPlacement,
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
