import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/attempt_history.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/student_pass_row.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/ui/exercise_title.dart' as title;
import 'package:billard_cfa/shared/ui/failure_message.dart';
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
  ) {
    final block = catalogue.blockById(ref.blockId);
    return title.exerciseTitle(
      l10n,
      blockTitle: block?.title ?? ref.blockId,
      number: ref.number,
      proposal: block?.isProposal ?? false,
    );
  }

  /// Bloc, numéro et taux : le libellé complet d'un exercice, sous-titre de
  /// l'exercice nommé et libellé de celui qui ne l'est pas.
  String _optionLabel(
    AppLocalizations l10n,
    ExerciseCatalogue catalogue,
    ExerciseSpec option,
  ) {
    final label = l10n.recordExerciseOption(
      catalogue.blockById(option.ref.blockId)!.title,
      option.ref.number,
      option.rate.successes,
      option.rate.attempts,
    );
    return option.isProposal ? l10n.proposalTagged(label) : label;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overview = state.overview!;
    final exercise = state.exercise!;
    final catalogue = overview.catalogue;
    final spec = catalogue.exercise(exercise)!;
    final compact =
        MediaQuery.sizeOf(context).width < StudentPassRow.compactBreakpoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Le nom évocateur de l'exercice (séance du catalogue notée) tient
        // lieu de libellé, le bloc et le numéro passent en sous-titre ; sans
        // nom connu, le libellé reste « bloc · n° (taux) ». Aucune
        // troncature : deux lignes et pleine largeur.
        DropdownMenu<ExerciseRef>(
          key: ValueKey('exercise-${exercise.blockId}-${exercise.number}'),
          expandedInsets: EdgeInsets.zero,
          maxLines: 2,
          label: Text(l10n.recordExercise),
          helperText: overview.exerciseName(exercise) == null
              ? null
              : _optionLabel(l10n, catalogue, spec),
          initialSelection: exercise,
          requestFocusOnTap: false,
          dropdownMenuEntries: [
            for (final option in catalogue.exercises)
              switch (overview.exerciseName(option.ref)) {
                final name? => DropdownMenuEntry(
                  value: option.ref,
                  label: name,
                  labelWidget: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name),
                      Text(
                        _optionLabel(l10n, catalogue, option),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                null => DropdownMenuEntry(
                  value: option.ref,
                  label: _optionLabel(l10n, catalogue, option),
                ),
              },
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
            child: StudentPassRow(
              studentName: student.firstName,
              spec: spec,
              passes: overview.passesFor(student.id, exercise),
              passedCount: overview.passedCount(student.id, exercise),
              maxPasses: overview.maxPassesPerExercise,
              passesRequired: overview.passesRequired,
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
          // Liste compacte : les lignes se suivent, séparées par un filet.
          if (!compact) const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.md),
        AttemptHistory(state: state),
      ],
    );
  }
}
