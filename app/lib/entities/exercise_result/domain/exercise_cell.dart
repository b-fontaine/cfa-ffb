import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_cell.freezed.dart';

/// État d'une case du parcours d'un élève (une case par exercice). Quatre
/// états distincts, dans cet ordre de priorité : acquis au positionnement
/// (ADR 0008), validé par passages, en cours, à faire.
enum ExerciseCellState { todo, inProgress, validated, acquired }

/// Une case du parcours : l'état de l'exercice, ses passages réussis et si une
/// alerte d'échecs consécutifs est active (non acquittée, ADR 0013).
@freezed
abstract class ExerciseCell with _$ExerciseCell {
  const factory ExerciseCell({
    required ExerciseRef exercise,
    required ExerciseCellState state,

    /// Passages réussis cumulés (jamais les échecs).
    required int passedCount,

    /// Alerte active sur un exercice en cours.
    required bool alerted,
  }) = _ExerciseCell;
}

/// Les cases des [exercises] d'un bloc pour l'élève de [progress], dans l'ordre
/// du bloc.
///
/// Un exercice d'un bloc acquis repris par des passages reprend l'état dérivé
/// de ces passages ; les autres exercices du bloc restent acquis.
List<ExerciseCell> exerciseCells({
  required List<ExerciseRef> exercises,
  required StudentProgress progress,
}) {
  final alerted = {for (final result in progress.activeAlerts) result.exercise};
  return [
    for (final exercise in exercises)
      () {
        final result = progress.results[exercise];
        final acquired = progress.acquiredExercises.contains(exercise);
        return ExerciseCell(
          exercise: exercise,
          state: acquired
              ? ExerciseCellState.acquired
              : result == null
              ? ExerciseCellState.todo
              : result.isValidated
              ? ExerciseCellState.validated
              : ExerciseCellState.inProgress,
          passedCount: result?.passedCount ?? 0,
          alerted: alerted.contains(exercise),
        );
      }(),
  ];
}
