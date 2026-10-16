import 'dart:math' as math;

import 'package:billard_cfa/entities/exercise_result/domain/exercise_cell.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/exercise_title.dart';
import 'package:billard_cfa/shared/ui/pass_dots.dart';
import 'package:billard_cfa/shared/ui/path_cell.dart';
import 'package:billard_cfa/shared/ui/path_cell_label.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// La vue « à montrer à l'élève » (décision Q6) : son prénom, l'exercice en
/// cours avec ses seules réussites, et son parcours en cases. Rien d'autre :
/// le modèle [StudentShowcase] n'a aucun champ pour une alerte, une note, un
/// bilan, l'assiduité ou un autre élève, et les cases ne répondent à aucun
/// toucher.
class ShowcaseView extends StatelessWidget {
  const ShowcaseView({required this.showcase, super.key});

  final StudentShowcase showcase;

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
    final current = showcase.current;
    final exerciseCount = showcase.rows.fold(
      0,
      (sum, row) => sum + row.cells.length,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          label: l10n.showcaseTitle(showcase.firstName),
          excludeSemantics: true,
          child: Text(
            showcase.firstName,
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (showcase.toStart)
          Text(l10n.sheetPathToStart, style: theme.textTheme.titleMedium)
        else ...[
          Text(
            l10n.sheetHeaderTechniques(
              showcase.finishedTechniques,
              showcase.techniqueCount,
            ),
            style: theme.textTheme.titleMedium,
          ),
          Text(
            l10n.sheetHeaderExercises(showcase.validatedCount),
            style: theme.textTheme.bodyLarge,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (current == null)
          Text(l10n.showcaseLevelDone, style: theme.textTheme.titleLarge)
        else
          SectionCard(
            title: l10n.showcaseCurrent,
            emphasis: SectionEmphasis.high,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exerciseTitle(
                    l10n,
                    blockTitle: current.blockTitle,
                    number: current.number,
                  ),
                  style: theme.textTheme.titleMedium,
                ),
                PassDots(
                  value: List.filled(
                    math.min(current.passed, current.required),
                    true,
                  ),
                  total: current.required,
                  readOnly: true,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: l10n.sheetPath,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PathLegend(exerciseCount: exerciseCount),
              const SizedBox(height: AppSpacing.sm),
              for (final (index, row) in showcase.rows.indexed)
                _Row(
                  key: ValueKey('showcase-row-$index'),
                  index: index,
                  row: row,
                  required: showcase.passesRequired,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.index,
    required this.row,
    required this.required,
    super.key,
  });

  final int index;
  final ShowcaseRow row;
  final int required;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final badge = switch (row.status) {
      ShowcaseRowStatus.todo => StatusBadge(
        tone: BadgeTone.neutral,
        label: l10n.statusNotStarted,
      ),
      ShowcaseRowStatus.inProgress => StatusBadge(
        tone: BadgeTone.neutral,
        label: l10n.statusInProgress,
      ),
      ShowcaseRowStatus.finished => StatusBadge(
        tone: BadgeTone.success,
        label: l10n.statusMastered,
      ),
      ShowcaseRowStatus.acquired => StatusBadge(
        tone: BadgeTone.success,
        label: l10n.statusAcquiredAtPlacement,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          badge,
          Wrap(
            children: [
              for (final cell in row.cells)
                PathCell(
                  key: ValueKey('showcase-cell-$index-${cell.number}'),
                  state: ShowcaseView._state(cell.state),
                  passed: cell.passed,
                  label: pathCellLabel(
                    l10n,
                    exercise: exerciseTitle(
                      l10n,
                      blockTitle: row.title,
                      number: cell.number,
                    ),
                    state: ShowcaseView._state(cell.state),
                    passed: cell.passed,
                    required: required,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
