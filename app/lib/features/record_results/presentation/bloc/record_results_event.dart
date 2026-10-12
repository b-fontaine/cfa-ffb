part of 'record_results_bloc.dart';

@freezed
sealed class RecordResultsEvent with _$RecordResultsEvent {
  const factory RecordResultsEvent.started({required SessionId sessionId}) =
      RecordResultsStarted;

  const factory RecordResultsEvent.exerciseSelected({
    required ExerciseRef exercise,
  }) = RecordResultsExerciseSelected;

  const factory RecordResultsEvent.passSubmitted({
    required StudentId studentId,
    required int potted,
    required int total,
  }) = RecordResultsPassSubmitted;
}
