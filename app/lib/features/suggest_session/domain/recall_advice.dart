import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recall_advice.freezed.dart';

/// Notion à rappeler à un élève : bloc, exercice conseillé et raison (R5).
@freezed
abstract class RecallAdvice with _$RecallAdvice {
  const factory RecallAdvice({
    required String blockId,
    required String blockTitle,
    required ExerciseRef exercise,
    required RecallReason reason,

    /// Le bloc est une proposition `[Prop]`, non fédérale.
    @Default(false) bool proposal,
  }) = _RecallAdvice;
}
