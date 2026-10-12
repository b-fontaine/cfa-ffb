part of 'session_planner_bloc.dart';

@freezed
abstract class SessionPlannerState with _$SessionPlannerState {
  const factory SessionPlannerState({
    @Default(<Session>[]) List<Session> sessions,
    @Default(false) bool titleInvalid,
  }) = _SessionPlannerState;
}
