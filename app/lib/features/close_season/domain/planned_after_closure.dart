import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Règle pure : les séances planifiées de [season] postérieures au jour de
/// clôture [day]. Une séance appartient à la saison par son groupe
/// ([groupIds], les groupes de la saison) ou, sans groupe, par sa date.
///
/// Partagée par l'aperçu (`PrepareSeasonClosure`) et l'effet réel
/// (`CloseSeason`) : ils ne peuvent pas diverger.
List<Session> plannedAfterClosure({
  required Season season,
  required Set<GroupId> groupIds,
  required Iterable<Session> planned,
  required DateTime day,
}) => [
  for (final session in planned)
    if ((session.groupId == null
            ? season.contains(session.date)
            : groupIds.contains(session.groupId)) &&
        session.date.dateOnly.isAfter(day.dateOnly))
      session,
];
