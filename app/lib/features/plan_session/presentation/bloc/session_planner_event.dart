part of 'session_planner_bloc.dart';

@freezed
sealed class SessionPlannerEvent with _$SessionPlannerEvent {
  const factory SessionPlannerEvent.started() = SessionPlannerStarted;

  const factory SessionPlannerEvent.sessionSubmitted({
    required String title,
    required Audience audience,
  }) = SessionPlannerSessionSubmitted;
}
