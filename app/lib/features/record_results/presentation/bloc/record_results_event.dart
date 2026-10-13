part of 'record_results_bloc.dart';

@freezed
sealed class RecordResultsEvent with _$RecordResultsEvent {
  /// [initialExercise] : numéro d'un exercice du bloc principal à
  /// présélectionner (lien profond depuis la séance guidée) ; ignoré s'il
  /// n'existe pas.
  const factory RecordResultsEvent.started({
    required SessionId sessionId,
    int? initialExercise,
  }) = RecordResultsStarted;

  const factory RecordResultsEvent.exerciseSelected({
    required ExerciseRef exercise,
  }) = RecordResultsExerciseSelected;

  const factory RecordResultsEvent.passSubmitted({
    required StudentId studentId,
    required int potted,
    required int total,
  }) = RecordResultsPassSubmitted;
}
