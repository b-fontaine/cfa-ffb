part of 'session_planner_bloc.dart';

@freezed
abstract class SessionPlannerState with _$SessionPlannerState {
  const factory SessionPlannerState({
    @Default(<PlannedSessionSummary>[]) List<PlannedSessionSummary> sessions,
    @Default(false) bool titleInvalid,

    /// Règle refusée à la dernière planification (date hors saison, groupe
    /// disparu) ; effacée à la saisie suivante.
    Failure? failure,

    /// Séances du catalogue proposables, dans l'ordre d'enseignement.
    @Default(<SheetOption>[]) List<SheetOption> sheetOptions,

    /// Vrai quand le catalogue n'a pas pu être lu : on planifie sans lien.
    @Default(false) bool sheetsUnavailable,

    /// Groupes de la saison en cours, proposables à la planification.
    @Default(<Group>[]) List<Group> groups,

    /// Séance du catalogue choisie pour la prochaine séance planifiée.
    SheetId? selectedSheet,

    /// Groupe choisi pour la prochaine séance planifiée ; `null` : sans
    /// groupe, le public se choisit à la main.
    GroupId? selectedGroup,

    /// Jour de la prochaine séance planifiée (le jour courant à l'ouverture).
    DateTime? date,

    /// Public de la prochaine séance planifiée (celui du groupe choisi).
    @Default(Audience.children) Audience audience,

    /// Titre en cours de saisie.
    @Default('') String title,

    /// Dernier titre proposé par une séance du catalogue : il est remplacé
    /// par celui de la séance suivante tant que [title] lui est égal.
    String? prefilledTitle,

    /// Nombre de séances planifiées depuis l'ouverture de l'écran : change à
    /// chaque planification réussie (le formulaire se vide alors).
    @Default(0) int plannedCount,
  }) = _SessionPlannerState;

  const SessionPlannerState._();

  /// Le groupe choisi, s'il est encore proposable.
  Group? get selectedGroupValue =>
      groups.where((group) => group.id == selectedGroup).firstOrNull;
}
