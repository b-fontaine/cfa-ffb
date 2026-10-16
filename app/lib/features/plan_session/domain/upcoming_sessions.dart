import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'upcoming_sessions.freezed.dart';

/// Ce que l'accueil « Aujourd'hui » montre des séances planifiées.
@freezed
abstract class UpcomingSessions with _$UpcomingSessions {
  const factory UpcomingSessions({
    /// La prochaine séance à donner ; `null` quand il n'y en a pas.
    PlannedSessionSummary? next,

    /// Autres séances à donner le même jour que [next].
    @Default(0) int sameDayOthers,

    /// Séances passées, avec groupe, sans saisie, des 7 derniers jours :
    /// « Noter les résultats », les plus récentes d'abord (au plus
    /// [toRecordLimit]).
    @Default(<PlannedSessionSummary>[]) List<PlannedSessionSummary> toRecord,

    /// Nom des groupes connus, pour libeller une séance guidée en cours.
    @Default(<GroupId, String>{}) Map<GroupId, String> groupNames,
  }) = _UpcomingSessions;
}

/// Nombre maximal de séances « à noter » montrées.
const toRecordLimit = 3;

/// Jours (avant aujourd'hui) pendant lesquels une séance sans saisie reste
/// « à noter ».
const toRecordDays = 7;

/// Les séances planifiées [summaries] (triées par date) vues d'[today].
UpcomingSessions upcomingOf(
  List<PlannedSessionSummary> summaries,
  DateTime today, {
  Map<GroupId, String> groupNames = const {},
}) {
  final day = today.dateOnly;
  final oldest = DateTime(day.year, day.month, day.day - toRecordDays);
  // Sans saisie : « faite » (ADR 0007, saisie du même groupe le même jour)
  // n'est plus à donner.
  final comingUp = [
    for (final summary in summaries)
      if (summary.recordId == null && !summary.session.date.isBefore(day))
        summary,
  ];
  final next = comingUp.firstOrNull;
  final sameDayOthers = next == null
      ? 0
      : comingUp
                .where((s) => s.session.date.isSameDayAs(next.session.date))
                .length -
            1;
  final toRecord = [
    for (final summary in summaries.reversed)
      if (summary.recordId == null &&
          summary.group != null &&
          summary.session.date.isBefore(day) &&
          !summary.session.date.isBefore(oldest))
        summary,
  ];
  return UpcomingSessions(
    next: next,
    sameDayOthers: sameDayOthers,
    toRecord: List.unmodifiable(toRecord.take(toRecordLimit)),
    groupNames: groupNames,
  );
}
