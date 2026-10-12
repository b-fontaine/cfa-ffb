import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/pass_entry_card.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Saisie des passages d'une séance ouverte : choix de l'exercice, une carte
/// par élève présent, historique des passages de la séance.
class RecordSessionView extends StatelessWidget {
  const RecordSessionView({required this.state, super.key});

  final RecordResultsState state;

  String _title(
    AppLocalizations l10n,
    ExerciseCatalogue catalogue,
    ExerciseRef ref,
  ) => l10n.sheetExerciseTitle(
    catalogue.blockById(ref.blockId)?.title ?? ref.blockId,
    ref.number,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final overview = state.overview!;
    final exercise = state.exercise!;
    final catalogue = overview.catalogue;
    final spec = catalogue.exercise(exercise)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownMenu<ExerciseRef>(
          key: ValueKey('exercise-${exercise.blockId}-${exercise.number}'),
          expandedInsets: EdgeInsets.zero,
          label: Text(l10n.recordExercise),
          initialSelection: exercise,
          requestFocusOnTap: false,
          dropdownMenuEntries: [
            for (final option in catalogue.exercises)
              DropdownMenuEntry(
                value: option.ref,
                label: l10n.recordExerciseOption(
                  catalogue.blockById(option.ref.blockId)!.title,
                  option.ref.number,
                  option.rate.successes,
                  option.rate.attempts,
                ),
              ),
          ],
          onSelected: (selected) {
            if (selected != null) {
              context.read<RecordResultsBloc>().add(
                RecordResultsEvent.exerciseSelected(exercise: selected),
              );
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        for (final student in overview.students) ...[
          KeyedSubtree(
            key: ValueKey('pass-card-${student.id.value}'),
            child: PassEntryCard(
              studentName: student.firstName,
              spec: spec,
              passesDone: overview.passesOf(student.id, exercise),
              maxPasses: overview.maxPassesPerExercise,
              feedback: state.feedback[student.id],
              nextExerciseLabel:
                  switch (state.feedback[student.id]?.nextExercise) {
                    final next? => _title(l10n, catalogue, next),
                    null => null,
                  },
              refusedMessage: switch (state.refused[student.id]) {
                final failure? => failureMessage(l10n, failure),
                null => null,
              },
              onSubmit: (potted, total) =>
                  context.read<RecordResultsBloc>().add(
                    RecordResultsEvent.passSubmitted(
                      studentId: student.id,
                      potted: potted,
                      total: total,
                    ),
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        SectionCard(
          title: l10n.recordHistory,
          child: overview.attempts.isEmpty
              ? Text(l10n.recordHistoryEmpty)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final attempt in overview.attempts)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          l10n.recordHistoryRow(
                            overview.students
                                .firstWhere((s) => s.id == attempt.studentId)
                                .firstName,
                            _title(l10n, catalogue, attempt.exercise),
                            attempt.potted,
                            attempt.total,
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
