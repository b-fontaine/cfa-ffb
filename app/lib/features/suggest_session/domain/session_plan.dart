import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_plan.freezed.dart';

/// Pourquoi une notion est proposée en rappel (par priorité décroissante).
enum RecallReason { groupFailure, activeAlert, lastFailed, stale }

/// Séance suggérée pour un groupe (R6).
@freezed
abstract class SessionPlan with _$SessionPlan {
  const factory SessionPlan({
    required Audience audience,
    required int durationMinutes,
    required String mainBlockId,
    required List<ExerciseRef> exercises,
    required List<PhaseSlot> phases,
    required int maxPassesPerExercise,
    String? recallBlockId,
    ExerciseRef? recallExercise,
    RecallReason? recallReason,
  }) = _SessionPlan;

  const SessionPlan._();

  /// Exercices du bloc principal puis exercice de rappel éventuel.
  List<ExerciseRef> get plannedExercises => [...exercises, ?recallExercise];

  int get phasesMinutes => phases.fold(0, (sum, slot) => sum + slot.minutes);
}
