part of 'suggested_session_bloc.dart';

enum SuggestedStatus { idle, loading, ready, failure }

@freezed
abstract class SuggestedSessionState with _$SuggestedSessionState {
  const factory SuggestedSessionState({
    @Default(SuggestedStatus.idle) SuggestedStatus status,
    GroupId? groupId,
    SessionPlan? plan,

    /// Fiches des exercices de la notion principale, dans l'ordre.
    @Default(<ExerciseSheet>[]) List<ExerciseSheet> exercises,
    ExerciseSheet? recall,
    Failure? failure,
  }) = _SuggestedSessionState;
}
