part of 'suggested_session_bloc.dart';

@freezed
sealed class SuggestedSessionEvent with _$SuggestedSessionEvent {
  const factory SuggestedSessionEvent.requested({
    required GroupId groupId,
    required Set<StudentId> expectedStudents,
  }) = SuggestedSessionRequested;
}
