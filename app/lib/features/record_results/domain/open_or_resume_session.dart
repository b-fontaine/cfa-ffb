import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : ouvrir la séance d'un groupe à une date, ou la reprendre si
/// elle existe déjà ce jour-là (les passages déjà saisis sont conservés, les
/// présents sont mis à jour). Évite les séances en double quand l'animateur
/// revient sur la saisie.
@injectable
class OpenOrResumeSession {
  OpenOrResumeSession(this._groups, this._sessions, this._open);

  final GroupRepository _groups;
  final SessionRecordRepository _sessions;
  final OpenSession _open;

  Future<Result<SessionRecord>> call({
    required GroupId groupId,
    required DateTime date,
    required Set<StudentId> present,
    String? mainBlockId,
    String? recallBlockId,
  }) async {
    final existing = [
      for (final session in await _sessions.forGroup(groupId))
        if (_sameDay(session.date, date)) session,
    ];
    if (existing.isEmpty) {
      return await _open(
        groupId: groupId,
        date: date,
        present: present,
        mainBlockId: mainBlockId,
        recallBlockId: recallBlockId,
      );
    }
    return await runGuarded(() async {
      final group = await _groups.byId(groupId);
      if (group == null) throw NotFound('group', groupId.value);
      if (!present.every((student) => group.isMemberOn(student, date))) {
        throw const InvariantViolation(InvariantCode.studentNotInGroup);
      }
      final resumed = existing.first.copyWith(
        present: present,
        mainBlockId: mainBlockId ?? existing.first.mainBlockId,
        recallBlockId: recallBlockId ?? existing.first.recallBlockId,
      );
      await _sessions.save(resumed);
      return resumed;
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
