import 'package:billard_cfa/entities/exercise_result/domain/exercise_cell.dart';
import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:billard_cfa/features/track_progress/domain/block_progress.dart';
import 'package:billard_cfa/features/track_progress/domain/path_row.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/ui/exercise_title.dart';
import 'package:billard_cfa/shared/ui/path_cell.dart';
import 'package:billard_cfa/shared/ui/path_cell_label.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Le parcours de l'élève : une ligne par technique (un bloc du catalogue, dans
/// l'ordre d'enseignement), une case par exercice. Chaque case a une forme et
/// un nom accessible qui disent son état (à faire, commencé, validé, issu du
/// positionnement) ; une alerte active ajoute une icône d'attention.
///
/// [onOpenExercise] est appelé au toucher d'une case (la page ouvre la courbe
/// de l'exercice). [onMarkAcquired] et [onRevokeAcquired] reçoivent
/// l'identifiant du bloc (positionnement, ADR 0008) : ils sont fournis par la
/// page, qui compose la fonctionnalité de positionnement, et leurs actions
/// vivent dans le menu ⋮ de la ligne. Sans eux, aucun menu.
class PathList extends StatelessWidget {
  const PathList({
    required this.sheet,
    this.onOpenExercise,
    this.onMarkAcquired,
    this.onRevokeAcquired,
    super.key,
  });

  final StudentSheet sheet;
  final ValueChanged<ExerciseRef>? onOpenExercise;
  final ValueChanged<String>? onMarkAcquired;
  final ValueChanged<String>? onRevokeAcquired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blocks = {for (final b in sheet.report.blocks) b.blockId: b};
    return SectionCard(
      key: const ValueKey('path-list'),
      title: l10n.sheetPath,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PathLegend(exerciseCount: sheet.header.exerciseCount),
          const SizedBox(height: AppSpacing.sm),
          for (final row in sheet.path)
            _TechniqueRow(
              key: ValueKey('path-row-${row.blockId}'),
              row: row,
              progress: blocks[row.blockId]!,
              sheet: sheet,
              onOpenExercise: onOpenExercise,
              onMarkAcquired: onMarkAcquired,
              onRevokeAcquired: onRevokeAcquired,
            ),
        ],
      ),
    );
  }
}

class _TechniqueRow extends StatelessWidget {
  const _TechniqueRow({
    required this.row,
    required this.progress,
    required this.sheet,
    required this.onOpenExercise,
    required this.onMarkAcquired,
    required this.onRevokeAcquired,
    super.key,
  });

  final PathRow row;
  final BlockProgress progress;
  final StudentSheet sheet;
  final ValueChanged<ExerciseRef>? onOpenExercise;
  final ValueChanged<String>? onMarkAcquired;
  final ValueChanged<String>? onRevokeAcquired;

  static PathCellState _state(ExerciseCellState state) => switch (state) {
    ExerciseCellState.todo => PathCellState.todo,
    ExerciseCellState.inProgress => PathCellState.started,
    ExerciseCellState.validated => PathCellState.validated,
    ExerciseCellState.acquired => PathCellState.acquired,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    final current = sheet.header.current;
    final open = onOpenExercise;
    final menu = _menu(context, l10n);
    final cells = Wrap(
      children: [
        for (final cell in row.summary.cells)
          PathCell(
            key: ValueKey('path-cell-${row.blockId}-${cell.exercise.number}'),
            state: _state(cell.state),
            passed: cell.passedCount,
            alerted: cell.alerted,
            current: cell.exercise == current,
            label: pathCellLabel(
              l10n,
              exercise: exerciseTitle(
                l10n,
                blockTitle: row.title,
                number: cell.exercise.number,
                proposal: row.proposal,
              ),
              state: _state(cell.state),
              passed: cell.passedCount,
              required: sheet.passesRequired,
              alerted: cell.alerted,
              current: cell.exercise == current,
            ),
            onTap: open == null ? null : () => open(cell.exercise),
          ),
        // Le menu ⋮ suit les cases : il prend la place qui reste sur la
        // dernière ligne plutôt qu'une ligne à lui.
        ?menu,
      ],
    );
    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(row.title, style: theme.textTheme.titleSmall),
              if (row.proposal) const ProposalBadge(),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // La fraction est écrite en chiffres ; le résumé complet (exercices et
        // séances) est lu par la sémantique.
        Semantics(
          label: l10n.sheetRowSummary(
            row.summary.doneCount,
            row.summary.total,
            progress.sessionsSpent,
          ),
          excludeSemantics: true,
          child: Text(
            l10n.sheetRowFraction(row.summary.doneCount, row.summary.total),
            style: theme.textTheme.labelLarge,
          ),
        ),
      ],
    );
    // Un statut n'est écrit que s'il dit autre chose que « commencé ou non » :
    // les cases et la fraction portent déjà celui-là.
    final status = _statusBadge(l10n, row.summary.status);
    final badges = [
      ?status,
      if (progress.overdue)
        StatusBadge(tone: BadgeTone.attention, label: l10n.sheetBlockOverdue),
    ];
    final acquiredOn = row.acquiredOn;
    final acquiredLine = acquiredOn == null
        ? null
        : Text(
            row.resumedCount == 0
                ? l10n.placementOn(dates.formatMediumDate(acquiredOn))
                : l10n.placementResumed(
                    dates.formatMediumDate(acquiredOn),
                    row.resumedCount,
                  ),
            style: theme.textTheme.bodySmall,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = [
            if (badges.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: badges,
                ),
              ),
            if (acquiredLine != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: acquiredLine,
              ),
          ];
          if (constraints.maxWidth >= 600) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, ...details],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: cells),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, ...details, cells],
          );
        },
      ),
    );
  }

  /// Le menu ⋮ du positionnement : « Retirer l'acquis » dès qu'un marqueur
  /// existe, « Marquer le bloc acquis » sinon, sauf pour un bloc déjà acquis
  /// par passages.
  Widget? _menu(BuildContext context, AppLocalizations l10n) {
    final onRevoke = onRevokeAcquired;
    final onMark = onMarkAcquired;
    final acquired = row.acquiredOn != null;
    if (acquired ? onRevoke == null : (onMark == null || _mastered)) {
      return null;
    }
    final tooltip = l10n.sheetPlacementMenu(row.title);
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: PopupMenuButton<bool>(
        tooltip: tooltip,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSpacing.minTouchTarget),
        ),
        onSelected: (revoke) =>
            revoke ? onRevoke!(row.blockId) : onMark!(row.blockId),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: acquired,
            child: Text(
              acquired ? l10n.placementRevokeAction : l10n.placementMarkAction,
            ),
          ),
        ],
      ),
    );
  }

  bool get _mastered => row.summary.status == BlockStatus.mastered;

  Widget? _statusBadge(AppLocalizations l10n, BlockStatus status) =>
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
        BlockStatus.inProgress || BlockStatus.notStarted => null,
      };
}
