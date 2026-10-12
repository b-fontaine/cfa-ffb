import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'student_progress.freezed.dart';

/// Résultats d'un élève par exercice (uniquement les exercices pratiqués).
@freezed
abstract class StudentProgress with _$StudentProgress {
  const factory StudentProgress({
    required StudentId studentId,
    required Map<ExerciseRef, ExerciseResult> results,
  }) = _StudentProgress;

  const StudentProgress._();

  /// Regroupe les [attempts] de l'élève par exercice et dérive chaque résultat.
  ///
  /// [rates] vient du catalogue ; un passage sur un exercice inconnu est une
  /// violation (`unknownExercise`).
  factory StudentProgress.derive({
    required StudentId studentId,
    required List<ExerciseAttempt> attempts,
    required Map<ExerciseRef, SuccessRate> rates,
    required RulesConfig config,
  }) {
    final byExercise = <ExerciseRef, List<ExerciseAttempt>>{};
    for (final attempt in attempts.where((a) => a.studentId == studentId)) {
      (byExercise[attempt.exercise] ??= []).add(attempt);
    }
    final results = <ExerciseRef, ExerciseResult>{};
    for (final entry in byExercise.entries) {
      final rate = rates[entry.key];
      if (rate == null) {
        throw const InvariantViolation(InvariantCode.unknownExercise);
      }
      results[entry.key] = ExerciseResult.derive(
        studentId: studentId,
        exercise: entry.key,
        rate: rate,
        attempts: entry.value,
        config: config,
      );
    }
    return StudentProgress(
      studentId: studentId,
      results: Map.unmodifiable(results),
    );
  }

  /// Exercices validés (entrée de `ExerciseCatalogue.nextExercise`).
  Set<ExerciseRef> get validated => {
    for (final result in results.values.where((r) => r.isValidated))
      result.exercise,
  };

  /// Exercices dont l'alerte d'échecs consécutifs est active (R4).
  List<ExerciseResult> get activeAlerts => [
    for (final result in results.values.where((r) => r.hasActiveAlert)) result,
  ];
}
