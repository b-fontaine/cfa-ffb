import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_attempt.freezed.dart';

/// Un passage d'un élève sur un exercice : une colonne « essai » de la fiche
/// résultats `[S]` (`potted` billes empochées sur `total`).
///
/// Le **rang** d'un passage (« passage 2 de la séance ») n'est ni saisi ni
/// stocké : il se dérive de l'ordre chronologique (date, puis ordre
/// d'enregistrement du dépôt : `createdAt` du serveur, puis identifiant ;
/// ADR 0024, décision 17, qui amende l'ADR 0006). Supprimer ou corriger un
/// passage ne renumérote donc rien.
@freezed
abstract class ExerciseAttempt with _$ExerciseAttempt {
  factory ExerciseAttempt({
    required AttemptId id,
    required StudentId studentId,
    required SessionId sessionId,
    required ExerciseRef exercise,
    required DateTime date,
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
  }

  double get ratio => potted / total;

  /// R1 : passage réussi au regard du taux requis de l'exercice.
  bool isPassed(SuccessRate rate) =>
      rate.isReachedBy(potted: potted, total: total);

  /// Vrai si le total saisi diffère des tentatives du catalogue `[Prop]` :
  /// l'évaluation se fait alors à la proportion.
  bool hasCustomTotal(SuccessRate rate) => total != rate.attempts;
}

/// Les [attempts] triés par date. À égalité de date, l'**ordre reçu** est
/// conservé (tri stable) : les dépôts rendent les passages dans l'ordre
/// d'enregistrement (`createdAt` puis identifiant), c'est le rang dérivé.
List<ExerciseAttempt> chronological(Iterable<ExerciseAttempt> attempts) {
  final indexed = attempts.toList().indexed.toList()
    ..sort((a, b) {
      final byDate = a.$2.date.compareTo(b.$2.date);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  return [for (final (_, attempt) in indexed) attempt];
}

/// Le rang (à partir de 1) de chaque passage parmi ceux de **sa séance, de son
/// élève et de son exercice**, dans l'ordre reçu (celui des dépôts).
Map<AttemptId, int> passRanks(Iterable<ExerciseAttempt> attempts) {
  final counts = <(SessionId, StudentId, ExerciseRef), int>{};
  return {
    for (final attempt in attempts)
      attempt.id: counts.update(
        (attempt.sessionId, attempt.studentId, attempt.exercise),
        (count) => count + 1,
        ifAbsent: () => 1,
      ),
  };
}
