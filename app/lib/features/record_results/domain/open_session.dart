import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : ouvrir la séance d'un groupe à une date, avec ses présents.
@injectable
class OpenSession {
  OpenSession(
    this._groups,
    this._seasons,
    this._sessions,
    this._catalogue,
    this._ids,
  );

  final GroupRepository _groups;
  final SeasonRepository _seasons;
  final SessionRecordRepository _sessions;
  final CatalogueRepository _catalogue;
  final IdGenerator _ids;

  Future<Result<SessionRecord>> call({
    required GroupId groupId,
    required DateTime date,
    required Set<StudentId> present,
    String? mainBlockId,
    String? recallBlockId,
  }) => runGuarded(() async {
    final group = await _groups.byId(groupId);
    if (group == null) throw NotFound('group', groupId.value);
    final season = await _seasons.byId(group.seasonId);
    if (season == null) throw NotFound('season', group.seasonId.value);
    if (!season.contains(date)) {
      throw const InvariantViolation(InvariantCode.seasonOutsidePeriod);
    }
    if (!present.every((student) => group.isMemberOn(student, date))) {
      throw const InvariantViolation(InvariantCode.studentNotInGroup);
    }
    final catalogue = await _catalogue.load();
    final blocks = [mainBlockId, recallBlockId].nonNulls;
    if (blocks.any((id) => catalogue.blockById(id) == null)) {
      throw const InvariantViolation(InvariantCode.unknownBlock);
    }
    final session = SessionRecord(
      id: SessionId(_ids.next()),
      groupId: groupId,
      seasonId: season.id,
      date: date,
      audience: group.audience,
      present: present,
      mainBlockId: mainBlockId,
      recallBlockId: recallBlockId,
    );
    await _sessions.save(session);
    return session;
  });
}
