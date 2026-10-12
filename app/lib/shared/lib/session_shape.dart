import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_shape.freezed.dart';

/// Phases d'une séance, dans l'ordre pédagogique `[S]`.
enum SessionPhase { welcome, notionAndInitiation, training, game, review }

/// Durée d'une phase de séance.
@freezed
abstract class PhaseSlot with _$PhaseSlot {
  const factory PhaseSlot({required SessionPhase phase, required int minutes}) =
      _PhaseSlot;
}

/// Forme d'une séance pour un public : minutage et nombre d'exercices `[Prop]`.
@freezed
abstract class SessionShape with _$SessionShape {
  const factory SessionShape({
    required List<PhaseSlot> phases,
    required int exerciseCount,
    required int recallCount,
  }) = _SessionShape;

  const SessionShape._();

  /// Phases dans l'ordre pédagogique, minutes positives dont la somme est la
  /// durée de [audience], au plus un rappel, au moins [minDistinctExercises]
  /// exercices au total.
  bool isValidFor(Audience audience, int minDistinctExercises) {
    final inOrder =
        phases.length == SessionPhase.values.length &&
        List.generate(
          phases.length,
          (index) => phases[index].phase == SessionPhase.values[index],
        ).every((same) => same);
    final minutes = phases.fold(0, (sum, slot) => sum + slot.minutes);
    return inOrder &&
        phases.every((slot) => slot.minutes >= 1) &&
        minutes == audience.sessionDuration.inMinutes &&
        recallCount >= 0 &&
        recallCount <= 1 &&
        exerciseCount >= 1 &&
        exerciseCount + recallCount >= minDistinctExercises;
  }
}
