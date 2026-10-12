part of 'assessment_bloc.dart';

@freezed
sealed class AssessmentEvent with _$AssessmentEvent {
  const factory AssessmentEvent.submitted({
    required StudentId studentId,
    required int concentration,
    required int endurance,
    required int frustration,
    String? comment,
  }) = AssessmentSubmitted;
}
