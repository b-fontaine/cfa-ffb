import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_failures.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';

/// Notion à rappeler (R5) : au plus une, ou aucune.
class RecallSuggestion {
  const RecallSuggestion({
    required this.blockId,
    required this.exercise,
    required this.reason,
  });

  final String blockId;
  final ExerciseRef exercise;
  final RecallReason reason;
}

class _BlockCandidate {
  const _BlockCandidate({
    required this.blockId,
    required this.teachingOrder,
    required this.exercise,
    required this.reason,
    required this.groupPriority,
    required this.hasAlert,
    required this.worstScore,
    required this.oldestPractice,
  });

  final String blockId;
  final int teachingOrder;
  final ExerciseRef exercise;
  final RecallReason reason;
  final bool groupPriority;
  final bool hasAlert;
  final double worstScore;
  final DateTime oldestPractice;
}

/// R5 : choisit la notion à rappeler pour les élèves de [progress].
///
/// Candidats : blocs déjà commencés (hors exercices acquis au positionnement),
/// hors [mainBlockId], avec (a) une alerte
/// active, (b) un dernier passage échoué ou (c) aucune pratique depuis
/// `recallStaleSessions` séances du groupe. Tri : bloc où au moins
/// `groupFailureSharePercent` % des élèves ont échoué au dernier passage, puis
/// alerte active, puis plus faible score relatif, puis pratique la plus
/// ancienne, puis plus petit `teachingOrder`.
RecallSuggestion? selectRecall({
  required ExerciseCatalogue catalogue,
  required Map<StudentId, StudentProgress> progress,
  required List<SessionRecord> groupSessions,
  required String mainBlockId,
  required RulesConfig config,
}) {
  final candidates = <_BlockCandidate>[];
  for (final block in catalogue.blocks.where((b) => b.id != mainBlockId)) {
    final triggered = <ExerciseResult>[];
    DateTime? oldest;
    for (final entry in progress.entries) {
      // Un exercice acquis au positionnement (marqueur sans passage depuis)
      // n'est pas rappelé : ses anciens passages sont dormants (ADR 0008).
      final results = blockResults(block.exerciseRefs, entry.value);
      if (results.isEmpty) continue;
      final latest = latestBlockResult(block.exerciseRefs, entry.value)!;
      final lastDate = latest.lastAttempt!.date;
      final failed = latest.lastFailed;
      final alert = results.any((r) => r.hasActiveAlert);
      final stale =
          groupSessions
              .where(
                (s) =>
                    s.present.contains(entry.key) && s.date.isAfter(lastDate),
              )
              .length >=
          config.recallStaleSessions;
      if (failed || alert || stale) {
        triggered.addAll(results);
        if (oldest == null || lastDate.isBefore(oldest)) oldest = lastDate;
      }
    }
    if (triggered.isEmpty) continue;
    // Même définition de « échouer » que les alertes de groupe.
    final failedStudents = blockFailedStudents(
      exercises: block.exerciseRefs,
      progress: progress,
    ).length;
    // Volontairement la part seule, sans `minGroupFailures` : le rappel peut
    // viser un seul échec dans un petit groupe (ADR 0013, décision verrouillée
    // par recall_selector_test) ; l'alerte de groupe, elle, exige le minimum.
    final groupPriority = reachesGroupFailureShare(
      failed: failedStudents,
      members: progress.length,
      sharePercent: config.groupFailureSharePercent,
    );
    final hasAlert = triggered.any((r) => r.hasActiveAlert);
    final chosen = [...triggered]..sort(_exercisePriority);
    candidates.add(
      _BlockCandidate(
        blockId: block.id,
        teachingOrder: block.teachingOrder,
        exercise: chosen.first.exercise,
        reason: groupPriority
            ? RecallReason.groupFailure
            : hasAlert
            ? RecallReason.activeAlert
            : failedStudents > 0
            ? RecallReason.lastFailed
            : RecallReason.stale,
        groupPriority: groupPriority,
        hasAlert: hasAlert,
        worstScore: chosen.first.lastRelativeScore!,
        oldestPractice: oldest!,
      ),
    );
  }
  if (candidates.isEmpty) return null;
  candidates.sort(_blockPriority);
  final best = candidates.first;
  return RecallSuggestion(
    blockId: best.blockId,
    exercise: best.exercise,
    reason: best.reason,
  );
}

int _exercisePriority(ExerciseResult a, ExerciseResult b) {
  if (a.hasActiveAlert != b.hasActiveAlert) return a.hasActiveAlert ? -1 : 1;
  final byScore = a.lastRelativeScore!.compareTo(b.lastRelativeScore!);
  return byScore != 0
      ? byScore
      : a.exercise.number.compareTo(b.exercise.number);
}

int _blockPriority(_BlockCandidate a, _BlockCandidate b) {
  if (a.groupPriority != b.groupPriority) return a.groupPriority ? -1 : 1;
  if (a.hasAlert != b.hasAlert) return a.hasAlert ? -1 : 1;
  final byScore = a.worstScore.compareTo(b.worstScore);
  if (byScore != 0) return byScore;
  final byAge = a.oldestPractice.compareTo(b.oldestPractice);
  return byAge != 0 ? byAge : a.teachingOrder.compareTo(b.teachingOrder);
}
