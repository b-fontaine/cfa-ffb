part of 'open_session_bloc.dart';

@freezed
sealed class OpenSessionEvent with _$OpenSessionEvent {
  const factory OpenSessionEvent.requested({
    required GroupId groupId,
    required DateTime date,
    required Set<StudentId> present,
    String? mainBlockId,
    String? recallBlockId,
  }) = OpenSessionRequested;
}
