part of 'session_planner_bloc.dart';

@freezed
sealed class SessionPlannerEvent with _$SessionPlannerEvent {
  /// [today] : date proposée pour la prochaine séance et jour de référence
  /// des groupes de la saison en cours. [sheetId] présélectionne une séance
  /// du catalogue (lien profond depuis le détail d'une séance) ; ignorée si
  /// le catalogue ne la connaît pas. [audience] reprend le public choisi dans
  /// ce détail.
  const factory SessionPlannerEvent.started({
    required DateTime today,
    SheetId? sheetId,
    @Default(Audience.children) Audience audience,
  }) = SessionPlannerStarted;

  /// Choix de la séance du catalogue ; `null` pour une séance libre.
  const factory SessionPlannerEvent.sheetSelected({SheetId? sheetId}) =
      SessionPlannerSheetSelected;

  /// Choix du groupe ; `null` pour une séance sans groupe. Le public suit
  /// celui du groupe choisi.
  const factory SessionPlannerEvent.groupSelected({GroupId? groupId}) =
      SessionPlannerGroupSelected;

  /// L'animateur a choisi le jour de la séance.
  const factory SessionPlannerEvent.dateChanged({required DateTime date}) =
      SessionPlannerDateChanged;

  /// Titre proposé par la séance du catalogue choisie (localisé par
  /// l'interface). Il remplace le titre tant que l'animateur n'y a pas
  /// touché : titre vide, ou égal à la proposition précédente.
  const factory SessionPlannerEvent.titleSuggested({required String title}) =
      SessionPlannerTitleSuggested;

  /// L'animateur a modifié le titre.
  const factory SessionPlannerEvent.titleEdited({required String title}) =
      SessionPlannerTitleEdited;

  /// L'animateur a choisi le public de la séance à planifier (sans groupe).
  const factory SessionPlannerEvent.audienceChanged({
    required Audience audience,
  }) = SessionPlannerAudienceChanged;

  /// Retire la séance planifiée [sessionId].
  const factory SessionPlannerEvent.sessionDeleted({
    required String sessionId,
  }) = SessionPlannerSessionDeleted;

  /// Planifie la séance avec le titre, la date, le groupe, le public et la
  /// séance du catalogue de l'état.
  const factory SessionPlannerEvent.sessionSubmitted() =
      SessionPlannerSessionSubmitted;
}
