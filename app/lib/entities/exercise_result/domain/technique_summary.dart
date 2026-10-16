import 'package:billard_cfa/entities/exercise_result/domain/exercise_cell.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'technique_summary.freezed.dart';

/// Statut d'un bloc pour un élève. [acquiredAtPlacement] (ADR 0008) : tous
/// les exercices du bloc sont acquis au positionnement, jamais confondu avec
/// [mastered] (validé par passages).
enum BlockStatus {
  notStarted,
  inProgress,
  mastered,
  acquiredAtPlacement,
  toReview,
}

/// Une technique (un bloc du catalogue) vue par un élève : ses cases, leurs
/// effectifs par état et son statut. Source unique pour la fiche de l'élève et
/// la carte de chaleur d'un groupe.
@freezed
abstract class TechniqueSummary with _$TechniqueSummary {
  const factory TechniqueSummary({
    required String blockId,
    required List<ExerciseCell> cells,
    required BlockStatus status,

    /// Exercices validés par passages (hors acquis).
    required int validated,

    /// Exercices acquis au positionnement.
    required int acquired,
    required int inProgress,
    required int todo,

    /// Exercices avec une alerte active.
    required int alerted,
  }) = _TechniqueSummary;

  const TechniqueSummary._();

  int get total => cells.length;

  /// Exercices validés ou acquis : le numérateur de la fraction affichée.
  int get doneCount => validated + acquired;

  /// Technique terminée : validée par passages ou acquise au positionnement.
  bool get isFinished =>
      status == BlockStatus.mastered ||
      status == BlockStatus.acquiredAtPlacement;
}

/// Résume le bloc [blockId] (ses [exercises], dans l'ordre) pour l'élève de
/// [progress].
///
/// Acquis = tous les exercices acquis au positionnement ; terminé par passages
/// = tous les exercices validés (par passages ou acquis) ; à revoir = alerte
/// active (non acquittée) ; démarré = au moins un passage sur le bloc.
TechniqueSummary techniqueSummary({
  required String blockId,
  required List<ExerciseRef> exercises,
  required StudentProgress progress,
}) {
  final cells = exerciseCells(exercises: exercises, progress: progress);
  int count(ExerciseCellState state) =>
      cells.where((cell) => cell.state == state).length;
  final validated = count(ExerciseCellState.validated);
  final acquired = count(ExerciseCellState.acquired);
  final alerted = cells.where((cell) => cell.alerted).length;
  final practised = exercises.any(progress.results.containsKey);
  final status = progress.isAcquired(blockId)
      ? BlockStatus.acquiredAtPlacement
      : !practised
      ? BlockStatus.notStarted
      : validated + acquired == cells.length
      ? BlockStatus.mastered
      : alerted > 0
      ? BlockStatus.toReview
      : BlockStatus.inProgress;
  return TechniqueSummary(
    blockId: blockId,
    cells: List.unmodifiable(cells),
    status: status,
    validated: validated,
    acquired: acquired,
    inProgress: count(ExerciseCellState.inProgress),
    todo: count(ExerciseCellState.todo),
    alerted: alerted,
  );
}
