import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_spec.freezed.dart';

/// Pont utilisé pour l'exercice (mention de la fiche, quand elle existe).
enum Bridge { frame, surface }

/// Un exercice du catalogue : taux requis et variantes `[S]`.
@freezed
abstract class ExerciseSpec with _$ExerciseSpec {
  const factory ExerciseSpec({
    required ExerciseRef ref,
    required SuccessRate rate,
    Bridge? bridge,
    @Default(false) bool bronze,
    String? note,
  }) = _ExerciseSpec;
}
