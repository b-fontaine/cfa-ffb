part of 'recorded_sessions_bloc.dart';

enum RecordedSessionsStatus { loading, ready, failure }

@freezed
abstract class RecordedSessionsState with _$RecordedSessionsState {
  const factory RecordedSessionsState({
    @Default(RecordedSessionsStatus.loading) RecordedSessionsStatus status,
    @Default(<RecordedSessionSummary>[]) List<RecordedSessionSummary> sessions,
    Failure? failure,
  }) = _RecordedSessionsState;
}
