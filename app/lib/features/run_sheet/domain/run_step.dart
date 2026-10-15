import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_step.freezed.dart';

/// Nature d'une étape de la séance guidée.
enum RunStepKind {
  recall,
  theory,
  initiation,
  exercise,

  /// Créneau d'exercice de rappel (ADR 0011), dernière étape de l'entraînement.
  recallExercise,
  game,
  review,
}

/// Une étape de la séance guidée : un élément de la séance affiché pour le
/// public choisi, avec ses minutes calculées `[Prop]`.
///
/// [elementId] désigne l'élément (section de théorie, initiation ou exercice) ;
/// il est absent pour le rappel, le créneau de rappel, le jeu et le bilan,
/// uniques.
@freezed
abstract class RunStep with _$RunStep {
  const factory RunStep({
    required RunStepKind kind,
    required SessionPhase phase,
    required int minutes,
    String? elementId,
  }) = _RunStep;

  const RunStep._();

  /// Exercice de la séance ou exercice du créneau de rappel : même rendu.
  bool get isExerciseLike =>
      kind == RunStepKind.exercise || kind == RunStepKind.recallExercise;
}
