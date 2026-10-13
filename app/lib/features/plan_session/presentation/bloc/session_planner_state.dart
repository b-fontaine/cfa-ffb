part of 'session_planner_bloc.dart';

@freezed
abstract class SessionPlannerState with _$SessionPlannerState {
  const factory SessionPlannerState({
    @Default(<Session>[]) List<Session> sessions,
    @Default(false) bool titleInvalid,

    /// Séances du catalogue proposables, dans l'ordre d'enseignement.
    @Default(<SheetOption>[]) List<SheetOption> sheetOptions,

    /// Vrai quand le catalogue n'a pas pu être lu : on planifie sans lien.
    @Default(false) bool sheetsUnavailable,

    /// Séance du catalogue choisie pour la prochaine séance planifiée.
    SheetId? selectedSheet,

    /// Public de la prochaine séance planifiée.
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
}
