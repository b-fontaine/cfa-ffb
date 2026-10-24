part of 'season_closure_bloc.dart';

enum SeasonClosureStatus {
  loading,

  /// Une clôture de cette saison, commencée par ce compte, est à reprendre.
  resumable,
  ready,

  /// En cours : `done` lots sur `total` (club synchronisé).
  closing,

  /// Arrêtée par l'animateur entre deux lots : reprendre pour terminer.
  stopped,

  /// Interrompue par le réseau : rien n'est perdu, reprendre plus tard.
  interrupted,

  /// Plafond d'écritures du jour atteint : reprendre un autre jour.
  paused,
  closed,
  failure,
}

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

    /// La clôture se fait dans le club, par lots reprenables.
    @Default(false) bool synchronized,

    /// Aperçu : invitations utilisées ou échues du club que la clôture
    /// supprimera (club synchronisé) ; `null` si elles n'ont pas pu être
    /// comptées (aucun chiffre montré, la clôture reste possible).
    int? invitationsToPurge,

    /// La clôture commencée à reprendre (`resumable`, `stopped`,
    /// `interrupted`, `paused`).
    ClosureTerms? pending,
    @Default(0) int done,
    @Default(0) int total,

    /// Compte rendu de la clôture (nombres seulement) ; absent d'une clôture
    /// reprise.
    ClosureResult? result,
    Failure? failure,
  }) = _SeasonClosureState;

  const SeasonClosureState._();

  int get erasedCount =>
      choices.values.where((c) => c == ClosureChoice.erase).length;

  int get keptCount => choices.length - erasedCount;

  /// Trop d'élèves à effacer pour une clôture par lots reprenables : refusée
  /// avant toute écriture.
  bool get tooManyToErase => synchronized && erasedCount > maxErasedPerClosure;
}
