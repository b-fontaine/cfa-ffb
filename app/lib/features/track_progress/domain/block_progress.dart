import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'block_progress.freezed.dart';

/// Statut d'un bloc pour un élève.
enum BlockStatus { notStarted, inProgress, mastered, toReview }

/// Avancement d'un élève sur un bloc d'entraînement (R3).
@freezed
abstract class BlockProgress with _$BlockProgress {
  const factory BlockProgress({
    required String blockId,
    required int validatedCount,
    required int exerciseCount,
    required BlockStatus status,
    required int sessionsSpent,
    required bool overdue,
  }) = _BlockProgress;

  const BlockProgress._();

  /// [sessionsSpent] : séances du bloc (voir [sessionsSpentOnBlock]).
  ///
  /// Acquis = tous les exercices validés ; à revoir = alerte active ; jamais
  /// bloquant : `overdue` n'est qu'un drapeau (nombre de séances approximatif).
  factory BlockProgress.of({
    required TrainingBlock block,
    required StudentProgress progress,
    required int sessionsSpent,
  }) {
    final results = [
      for (final spec in block.exercises) ?progress.results[spec.ref],
    ];
    final validated = results.where((r) => r.isValidated).length;
    final mastered = validated == block.exercises.length;
    final status = results.isEmpty
        ? BlockStatus.notStarted
        : mastered
        ? BlockStatus.mastered
        : results.any((r) => r.hasActiveAlert)
        ? BlockStatus.toReview
        : BlockStatus.inProgress;
    return BlockProgress(
      blockId: block.id,
      validatedCount: validated,
      exerciseCount: block.exercises.length,
      status: status,
      sessionsSpent: sessionsSpent,
      overdue: !mastered && sessionsSpent > block.recommendedSessions.max,
    );
  }

  /// Part d'exercices validés, en pourcentage entier (arrondi inférieur).
  int get percentValidated => validatedCount * 100 ~/ exerciseCount;
}

/// R3 : séances où l'élève était présent et où le bloc est notion principale,
/// rappel, ou comporte un de ses passages.
int sessionsSpentOnBlock({
  required TrainingBlock block,
  required StudentId studentId,
  required List<ExerciseAttempt> attempts,
  required List<SessionRecord> sessions,
}) {
  final practised = {
    for (final attempt in attempts)
      if (attempt.exercise.blockId == block.id) attempt.sessionId,
  };
  return sessions
      .where(
        (s) =>
            s.present.contains(studentId) &&
            (s.mainBlockId == block.id ||
                s.recallBlockId == block.id ||
                practised.contains(s.id)),
      )
      .length;
}
