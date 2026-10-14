part of 'record_results_bloc.dart';

enum RecordStatus { loading, ready, failure }

/// Dernier changement apporté à un passage déjà saisi (ADR 0006).
@freezed
sealed class AttemptChange with _$AttemptChange {
  const factory AttemptChange.corrected({required ExerciseAttempt attempt}) =
      AttemptCorrected;
  const factory AttemptChange.deleted() = AttemptDeleted;
}

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

    /// Dernière correction ou suppression d'un passage.
    AttemptChange? attemptChange,

    /// Dernière correction ou suppression refusée.
    Failure? attemptRefused,
    Failure? failure,
  }) = _RecordResultsState;
}
