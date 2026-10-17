import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Groupes persistés dans SQLite (drift).
@LazySingleton(as: GroupRepository, env: [Environment.prod])
class DriftGroupRepository implements GroupRepository {
  DriftGroupRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Future<void> save(Group group) => _db.transaction(() async {
    final now = _clock.now();
    await _db
        .into(_db.groups)
        .insert(
          GroupsCompanion.insert(
            id: group.id.value,
            seasonId: group.seasonId.value,
            name: group.name,
            audience: group.audience.name,
            createdAt: now,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => GroupsCompanion(
              seasonId: Value(group.seasonId.value),
              name: Value(group.name),
              audience: Value(group.audience.name),
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
            target: [_db.groups.id],
          ),
        );
    await (_db.delete(
      _db.groupMemberships,
    )..where((m) => m.groupId.equals(group.id.value))).go();
    await _db.batch(
      (batch) => batch.insertAll(_db.groupMemberships, [
        for (final (index, membership) in group.memberships.indexed)
          GroupMembershipsCompanion.insert(
            groupId: group.id.value,
            position: index,
            studentId: membership.studentId.value,
            fromDate: membership.from,
            toDate: Value(membership.to),
          ),
      ]),
    );
  });

  @override
  Future<Group?> byId(GroupId id) async {
    final row =
        await (_db.select(_db.groups)
              ..where((g) => g.id.equals(id.value) & g.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) return null;
    return (await _hydrate([row])).single;
  }

  @override
  Future<List<Group>> all() async {
    final rows =
        await (_db.select(_db.groups)
              ..where((g) => g.deletedAt.isNull())
              ..orderBy([(g) => OrderingTerm.asc(g.seq)]))
            .get();
    return await _hydrate(rows);
  }

  @override
  Future<void> delete(GroupId id) =>
      (_db.update(_db.groups)..where((g) => g.id.equals(id.value))).write(
        GroupsCompanion(deletedAt: Value(_clock.now())),
      );

  @override
  Future<void> eraseStudent(StudentId studentId) => (_db.delete(
    _db.groupMemberships,
  )..where((m) => m.studentId.equals(studentId.value))).go();

  @override
  Future<Set<GroupId>> idsEverContaining(StudentId studentId) async {
    final column = _db.groupMemberships.groupId;
    final rows =
        await (_db.selectOnly(_db.groupMemberships, distinct: true)
              ..addColumns([column])
              ..where(_db.groupMemberships.studentId.equals(studentId.value)))
            .get();
    return {for (final row in rows) GroupId(row.read(column)!)};
  }

  Future<List<Group>> _hydrate(List<GroupRow> rows) async {
    final memberships =
        await (_db.select(_db.groupMemberships)
              ..where((m) => m.groupId.isIn([for (final r in rows) r.id]))
              ..orderBy([(m) => OrderingTerm.asc(m.position)]))
            .get();
    return [
      for (final row in rows)
        Group(
          id: GroupId(row.id),
          seasonId: SeasonId(row.seasonId),
          name: row.name,
          audience: Audience.values.byName(row.audience),
          memberships: [
            for (final m in memberships.where((m) => m.groupId == row.id))
              Membership(
                studentId: StudentId(m.studentId),
                from: m.fromDate,
                to: m.toDate,
              ),
          ],
        ),
    ];
  }
}
