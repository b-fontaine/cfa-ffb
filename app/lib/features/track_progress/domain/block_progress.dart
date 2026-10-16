import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'block_progress.freezed.dart';

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

    /// Jour du positionnement quand le bloc est marqué acquis (y compris
    /// partiellement ou entièrement repris par des passages) ; sinon `null`.
    required DateTime? acquiredOn,

    /// Exercices du bloc repris par des passages depuis le positionnement.
    required int resumedCount,
  }) = _BlockProgress;

  const BlockProgress._();

  /// [sessionsSpent] : séances du bloc (voir [sessionsSpentOnBlock]).
  ///
  /// Acquis = tous les exercices validés (par passages ou acquis au
  /// positionnement) ; à revoir = alerte active ; jamais bloquant : `overdue`
  /// n'est qu'un drapeau (nombre de séances approximatif). Un bloc dont tous
  /// les exercices sont acquis au positionnement n'est jamais en retard.
  factory BlockProgress.of({
    required TrainingBlock block,
    required StudentProgress progress,
    required int sessionsSpent,
  }) {
    final summary = techniqueSummary(
      blockId: block.id,
      exercises: block.exerciseRefs,
      progress: progress,
    );
    final acquired = progress.isAcquired(block.id);
    final mastered = summary.doneCount == summary.total;
    return BlockProgress(
      blockId: block.id,
      validatedCount: summary.doneCount,
      exerciseCount: summary.total,
      status: summary.status,
      sessionsSpent: sessionsSpent,
      overdue:
          !acquired &&
          !mastered &&
          sessionsSpent > block.recommendedSessions.max,
      acquiredOn: progress.acquiredOn(block.id),
      resumedCount: progress.resumedCount(block.id),
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
