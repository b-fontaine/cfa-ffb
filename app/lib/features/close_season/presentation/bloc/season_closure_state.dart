part of 'season_closure_bloc.dart';

enum SeasonClosureStatus { loading, ready, closing, closed, failure }

@freezed
abstract class SeasonClosureState with _$SeasonClosureState {
  const factory SeasonClosureState({
    @Default(SeasonClosureStatus.loading) SeasonClosureStatus status,
    ClosurePlan? plan,

    /// Le choix courant de chaque élève (la proposition, modifiée).
    @Default(<StudentId, ClosureChoice>{})
    Map<StudentId, ClosureChoice> choices,

    /// Préparer la saison suivante (cochée par défaut, U11-8).
    @Default(true) bool prepareNext,

    /// Supprimer les séances planifiées postérieures à la clôture (U11-11).
    @Default(true) bool dropPlanned,

    /// Compte rendu de la clôture (nombres seulement).
    ClosureResult? result,
    Failure? failure,
  }) = _SeasonClosureState;

  const SeasonClosureState._();

  int get erasedCount =>
      choices.values.where((c) => c == ClosureChoice.erase).length;

  int get keptCount => choices.length - erasedCount;
}
