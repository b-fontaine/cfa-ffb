part of 'recorded_sessions_bloc.dart';

@freezed
sealed class RecordedSessionsEvent with _$RecordedSessionsEvent {
  const factory RecordedSessionsEvent.started() = RecordedSessionsStarted;
  const factory RecordedSessionsEvent.refreshed() = RecordedSessionsRefreshed;
}
