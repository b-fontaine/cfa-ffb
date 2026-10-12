part of 'record_results_bloc.dart';

enum RecordStatus { loading, ready, failure }

@freezed
abstract class RecordResultsState with _$RecordResultsState {
  const factory RecordResultsState({
    @Default(RecordStatus.loading) RecordStatus status,
    SessionOverview? overview,

    /// Exercice en cours de saisie.
    ExerciseRef? exercise,

    /// Dernier passage enregistré par élève pour l'exercice courant.
    @Default(<StudentId, RecordedAttempt>{})
    Map<StudentId, RecordedAttempt> feedback,

    /// Dernier passage refusé par élève (règle violée).
    @Default(<StudentId, Failure>{}) Map<StudentId, Failure> refused,
    Failure? failure,
  }) = _RecordResultsState;
}
