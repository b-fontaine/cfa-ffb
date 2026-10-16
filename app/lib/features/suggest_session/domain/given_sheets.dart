import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';

/// Les séances du catalogue **déjà données** à un groupe (ADR 0009 S7), avec
/// la date de la dernière fois : une saisie avec séance du catalogue **et** au
/// moins un passage ([attemptCountBySession]), datée d'aujourd'hui ([today])
/// ou avant. Une saisie sans séance, sans passage ou à venir ne compte pas.
///
/// Règle unique de « faite » : la suggestion (`suggestSheet`) et le marqueur
/// de parcours du catalogue l'appellent toutes deux. Pure : ni dépôt, ni
/// horloge, ni effet de bord.
Map<SheetId, DateTime> givenSheets({
  required Iterable<SessionRecord> groupSessions,
  required Map<SessionId, int> attemptCountBySession,
  required DateTime today,
}) {
  final limit = today.dateOnly;
  final lastGiven = <SheetId, DateTime>{};
  for (final session in groupSessions) {
    final sheetId = session.sheetId;
    if (sheetId == null) continue;
    if ((attemptCountBySession[session.id] ?? 0) == 0) continue;
    final given = session.date.dateOnly;
    if (given.isAfter(limit)) continue;
    final known = lastGiven[sheetId];
    if (known == null || given.isAfter(known)) lastGiven[sheetId] = given;
  }
  return lastGiven;
}
