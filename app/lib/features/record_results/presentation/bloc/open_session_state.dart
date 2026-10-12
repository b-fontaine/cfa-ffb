part of 'open_session_bloc.dart';

enum OpenSessionStatus { idle, opening, opened, failure }

@freezed
abstract class OpenSessionState with _$OpenSessionState {
  const factory OpenSessionState({
    @Default(OpenSessionStatus.idle) OpenSessionStatus status,
    SessionRecord? session,
    Failure? failure,
  }) = _OpenSessionState;
}
