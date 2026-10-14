import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : les séances planifiées par date croissante (à date égale,
/// dans l'ordre de planification), avec leur groupe et la saisie du même
/// groupe le même jour (ADR 0007).
@injectable
class ListSessions {
  ListSessions(this._sessions, this._groups, this._records);

  final SessionRepository _sessions;
  final GroupRepository _groups;
  final SessionRecordRepository _records;

  Future<List<PlannedSessionSummary>> call() async {
    final sessions = await _sessions.getAll();
    final groups = <GroupId, Group?>{};
    final records = <GroupId, List<SessionRecord>>{};
    final summaries = <PlannedSessionSummary>[];
    for (final session in sessions) {
      final groupId = session.groupId;
      Group? group;
      SessionId? recordId;
      if (groupId != null) {
        group = groups[groupId] ??= await _groups.byId(groupId);
        final recorded = records[groupId] ??= await _records.forGroup(groupId);
        recordId = recorded
            .where((record) => record.date.isSameDayAs(session.date))
            .firstOrNull
            ?.id;
      }
      summaries.add(
        PlannedSessionSummary(
          session: session,
          group: group,
          recordId: recordId,
        ),
      );
    }
    // `getAll()` rend l'ordre de planification : l'indice départage les
    // séances d'un même jour.
    final planned = {
      for (final (index, summary) in summaries.indexed) summary: index,
    };
    summaries.sort((a, b) {
      final byDate = a.session.date.compareTo(b.session.date);
      return byDate != 0 ? byDate : planned[a]!.compareTo(planned[b]!);
    });
    return List.unmodifiable(summaries);
  }
}
