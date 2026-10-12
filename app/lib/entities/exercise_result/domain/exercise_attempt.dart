import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_attempt.freezed.dart';

/// Un passage d'un élève sur un exercice : une colonne « essai » de la fiche
/// résultats `[S]` (`potted` billes empochées sur `total`).
@freezed
abstract class ExerciseAttempt with _$ExerciseAttempt {
  factory ExerciseAttempt({
    required AttemptId id,
    required StudentId studentId,
    required SessionId sessionId,
    required ExerciseRef exercise,
    required DateTime date,
    required int passIndex,
    required int potted,
    required int total,
  }) = _ExerciseAttempt;

  ExerciseAttempt._() {
    if (total < 1 || total > SuccessRate.maxAttempts) {
      throw const InvariantViolation(InvariantCode.totalOutOfRange);
    }
    if (potted < 0) {
      throw const InvariantViolation(InvariantCode.negativePotted);
    }
    if (potted > total) {
      throw const InvariantViolation(InvariantCode.pottedExceedsTotal);
    }
    if (passIndex < 1) {
      throw const InvariantViolation(InvariantCode.invalidPassIndex);
    }
  }

  double get ratio => potted / total;

  /// R1 : passage réussi au regard du taux requis de l'exercice.
  bool isPassed(SuccessRate rate) =>
      rate.isReachedBy(potted: potted, total: total);

  /// Vrai si le total saisi diffère des tentatives du catalogue `[Prop]` :
  /// l'évaluation se fait alors à la proportion.
  bool hasCustomTotal(SuccessRate rate) => total != rate.attempts;
}
