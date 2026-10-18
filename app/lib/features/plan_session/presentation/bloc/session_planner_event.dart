part of 'session_planner_bloc.dart';

@freezed
sealed class SessionPlannerEvent with _$SessionPlannerEvent {
  /// [today] : date proposée pour la prochaine séance et jour de référence
  /// des groupes de la saison en cours. [sheetId] présélectionne une séance
  /// du catalogue (lien profond depuis le détail d'une séance) ; ignorée si
  /// le catalogue ne la connaît pas. [groupId] présélectionne le groupe choisi
  /// dans le catalogue ; ignoré s'il n'est pas planifiable.
  const factory SessionPlannerEvent.started({
    required DateTime today,
    SheetId? sheetId,
    GroupId? groupId,
  }) = SessionPlannerStarted;

  /// Choix de la séance du catalogue ; `null` pour une séance libre.
  const factory SessionPlannerEvent.sheetSelected({SheetId? sheetId}) =
      SessionPlannerSheetSelected;

  /// Choix du groupe de la séance (obligatoire). Le public est celui du groupe.
  const factory SessionPlannerEvent.groupSelected({required GroupId groupId}) =
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

  /// Retire la séance planifiée [sessionId].
  const factory SessionPlannerEvent.sessionDeleted({
    required String sessionId,
  }) = SessionPlannerSessionDeleted;

  /// Planifie la séance avec le titre, la date, le groupe et la séance du
  /// catalogue de l'état.
  const factory SessionPlannerEvent.sessionSubmitted() =
      SessionPlannerSessionSubmitted;
}
