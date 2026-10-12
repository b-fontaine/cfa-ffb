import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recorded_attempt.freezed.dart';

/// Ce que l'animateur voit juste après avoir saisi un passage.
@freezed
abstract class RecordedAttempt with _$RecordedAttempt {
  const factory RecordedAttempt({
    required ExerciseAttempt attempt,

    /// Résultat dérivé de l'exercice après ce passage (statut, alerte…).
    required ExerciseResult result,

    /// Le passage atteint le taux requis (R1).
    required bool passed,

    /// Ce passage est celui qui valide l'exercice.
    required bool justValidated,

    /// Exercice suivant recommandé (R2) ; `null` quand le niveau est terminé.
    required ExerciseRef? nextExercise,
  }) = _RecordedAttempt;
}
