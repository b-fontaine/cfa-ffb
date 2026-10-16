part of 'season_closure_bloc.dart';

@freezed
sealed class SeasonClosureEvent with _$SeasonClosureEvent {
  const factory SeasonClosureEvent.started({required SeasonId seasonId}) =
      SeasonClosureStarted;

  /// Reconduire ou effacer un élève (la proposition de la règle est modifiée).
  const factory SeasonClosureEvent.choiceSet({
    required StudentId studentId,
    required ClosureChoice choice,
  }) = SeasonClosureChoiceSet;

  /// « Tout reconduire » / « Tout effacer ».
  const factory SeasonClosureEvent.allSet({required ClosureChoice choice}) =
      SeasonClosureAllSet;

  const factory SeasonClosureEvent.prepareNextSet({required bool value}) =
      SeasonClosurePrepareNextSet;

  const factory SeasonClosureEvent.dropPlannedSet({required bool value}) =
      SeasonClosureDropPlannedSet;

  /// L'animateur a confirmé (case « J'ai compris » cochée si des élèves sont
  /// à effacer).
  const factory SeasonClosureEvent.confirmed() = SeasonClosureConfirmed;
}
