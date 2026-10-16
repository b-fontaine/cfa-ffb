part of 'acknowledgement_bloc.dart';

@freezed
sealed class AcknowledgementEvent with _$AcknowledgementEvent {
  const factory AcknowledgementEvent.acknowledgeRequested({
    required StudentId studentId,
    required ExerciseRef exercise,
  }) = AcknowledgementAcknowledgeRequested;

  const factory AcknowledgementEvent.restoreRequested({
    required StudentId studentId,
    required ExerciseRef exercise,
  }) = AcknowledgementRestoreRequested;
}
