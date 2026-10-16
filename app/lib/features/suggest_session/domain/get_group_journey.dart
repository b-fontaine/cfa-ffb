import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/features/suggest_session/domain/given_sheets.dart';
import 'package:billard_cfa/features/suggest_session/domain/group_journey.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_next_sheet.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : le parcours d'un groupe dans le catalogue de séances.
///
/// « Faite » est la règle de la suggestion ([givenSheets], ADR 0009),
/// « suivante » est [SuggestNextSheet] tel quel : rien n'est recalculé ici.
/// Les élèves attendus sont les membres du groupe aujourd'hui ; sans élève,
/// aucune séance n'est recommandée mais les séances faites restent connues.
/// Groupe inconnu : [NotFound].
@injectable
class GetGroupJourney {
  GetGroupJourney(
    this._groups,
    this._sessions,
    this._attempts,
    this._sheets,
    this._next,
    this._clock,
  );

  final GroupRepository _groups;
  final SessionRecordRepository _sessions;
  final AttemptRepository _attempts;
  final SessionSheetRepository _sheets;
  final SuggestNextSheet _next;
  final Clock _clock;

  Future<Result<GroupJourney>> call(GroupId groupId) => runGuarded(() async {
    final group = await _groups.byId(groupId);
    if (group == null) throw NotFound('group', groupId.value);
    final today = _clock.today();
    final groupSessions = await _sessions.forGroup(groupId);
    final done = givenSheets(
      groupSessions: groupSessions,
      attemptCountBySession: {
        for (final session in groupSessions)
          if (session.sheetId != null)
            session.id: (await _attempts.forSession(session.id)).length,
      },
      today: today,
    );
    final catalogue = {for (final sheet in await _sheets.getAll()) sheet.id};
    final knownDone = {
      for (final entry in done.entries)
        if (catalogue.contains(entry.key)) entry.key: entry.value,
    };
    final members = group.membersOn(today).toSet();
    if (members.isEmpty) {
      return GroupJourney(done: knownDone, noStudents: true);
    }
    final next = switch (await _next(groupId: groupId, present: members)) {
      Ok(:final value) => value.sheet?.option.id,
      Err(:final failure) => throw failure,
    };
    return GroupJourney(done: knownDone, next: next);
  });
}
