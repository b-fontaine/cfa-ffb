import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:billard_cfa/entities/exercise_result/domain/watch_list.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_header.freezed.dart';

/// Alerte vue par l'animateur (« Vu », ADR 0013) : l'exercice, le jour du
/// « Vu » et l'état de l'alerte qu'il masque.
@freezed
abstract class AcknowledgedAlert with _$AcknowledgedAlert {
  const factory AcknowledgedAlert({
    required ExerciseRef exercise,
    required DateTime date,
    required AlertLevel alert,
    required int consecutiveFailures,
  }) = _AcknowledgedAlert;
}

/// En-tête de la fiche d'un élève : l'exercice en cours, le prochain, le total
/// de techniques et d'exercices (jamais présenté comme un score), l'alerte la
/// plus grave et les alertes déjà vues.
@freezed
abstract class SheetHeader with _$SheetHeader {
  const factory SheetHeader({
    /// Premier exercice non validé dans l'ordre d'enseignement (R2) ; `null`
    /// quand le niveau est terminé.
    required ExerciseRef? current,

    /// Passages réussis de l'exercice en cours.
    required int currentPassed,
    required int passesRequired,

    /// Premier exercice non validé après [current] ; `null` s'il n'y en a pas.
    required ExerciseRef? next,

    /// Techniques terminées (par passages ou acquises au positionnement).
    required int finishedTechniques,
    required int techniqueCount,

    /// Exercices validés ou acquis.
    required int validatedExercises,
    required int exerciseCount,

    /// Aucun passage et rien d'acquis : « Parcours à commencer », pas « 0 sur
    /// 70 ». Un élève qui a pratiqué sans rien valider n'est plus à commencer.
    required bool toStart,

    /// Tous les exercices du catalogue sont validés ou acquis.
    required bool levelCompleted,

    /// Alerte la plus grave (même règle que les élèves à surveiller) ;
    /// `null` sans alerte active.
    required WatchedStudent? alert,

    /// Alertes vues par l'animateur, de la plus grave à la moins grave.
    required List<AcknowledgedAlert> acknowledged,
  }) = _SheetHeader;

  const SheetHeader._();

  /// Dérive l'en-tête de [progress] (fabrique pure).
  ///
  /// « En cours » est le premier exercice non validé dans l'ordre
  /// d'enseignement (on ne saute jamais un exercice, R2) : c'est aussi celui
  /// de la séance suggérée. « Prochain » est le suivant non validé.
  factory SheetHeader.derive({
    required ExerciseCatalogue catalogue,
    required StudentProgress progress,
    required int passesRequired,
  }) {
    final order = [for (final spec in catalogue.exercises) spec.ref];
    final validated = progress.validated;
    final current = catalogue.nextExercise(validated: validated);
    final next = current == null
        ? null
        : order
              .skipWhile((exercise) => exercise != current)
              .skip(1)
              .where((exercise) => !validated.contains(exercise))
              .firstOrNull;
    final ranks = teachingRanks(order);
    final acknowledged = [
      for (final result in progress.acknowledgedAlertResults)
        (result, progress.acknowledgedAlerts[result.exercise]!.date),
    ]..sort((a, b) => compareAlertSeverity(a.$1, b.$1, ranks: ranks));
    return SheetHeader(
      current: current,
      currentPassed: current == null
          ? 0
          : progress.results[current]?.passedCount ?? 0,
      passesRequired: passesRequired,
      next: next,
      finishedTechniques: catalogue.blocks
          .where(
            (block) => techniqueSummary(
              blockId: block.id,
              exercises: block.exerciseRefs,
              progress: progress,
            ).isFinished,
          )
          .length,
      techniqueCount: catalogue.blocks.length,
      validatedExercises: validated.length,
      exerciseCount: order.length,
      toStart: progress.toStart,
      levelCompleted: current == null,
      alert: watchedStudents([progress], catalogueOrder: order).firstOrNull,
      acknowledged: List.unmodifiable([
        for (final (result, date) in acknowledged)
          AcknowledgedAlert(
            exercise: result.exercise,
            date: date,
            alert: result.alert,
            consecutiveFailures: result.consecutiveFailures,
          ),
      ]),
    );
  }
}
