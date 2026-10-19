import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/manage_groups/domain/move_student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/in_memory_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late MoveStudent move;

  const s1 = StudentId('s1');
  const origin = GroupId('g1');
  const target = GroupId('g2');

  Future<void> addGroup(
    String id, {
    Audience audience = Audience.children,
    String season = 'season',
  }) => world.groups.save(
    Group(
      id: GroupId(id),
      seasonId: SeasonId(season),
      name: 'Groupe $id',
      audience: audience,
    ),
  );

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
    await addGroup('g2');
    move = MoveStudent(
      world.students,
      world.groups,
      world.seasons,
      world.sessions,
      InMemoryUnitOfWork(),
    );
  });

  Future<Result<Group>> moveOn(int dayOfMonth, {GroupId to = target}) =>
      move(studentId: s1, toGroupId: to, on: day(dayOfMonth));

  test(
    'closes the origin the day before and opens the target on the day',
    () async {
      final destination = ok(await moveOn(10));

      final from = (await world.groups.byId(origin))!;
      expect(from.memberships.single.to, day(9));
      expect(from.isMemberOn(s1, day(9)), isTrue);
      expect(from.isMemberOn(s1, day(10)), isFalse);
      expect(destination.id, target);
      expect(destination.memberships.single.from, day(10));
      expect(destination.isMemberOn(s1, day(9)), isFalse);
      expect(destination.isMemberOn(s1, day(10)), isTrue);
      expect(await world.groups.byId(target), destination);
    },
  );

  test('copies and rewrites nothing: sessions and attempts stay', () async {
    await world.session(dayOfMonth: 3);
    await world.attempts.add(attempt(ref('a', 1), potted: 3, dayOfMonth: 3));
    final sessionsBefore = await world.sessions.all();
    final attemptsBefore = await world.attempts.all();

    ok(await moveOn(10));

    expect(await world.sessions.all(), sessionsBefore);
    expect(await world.attempts.all(), attemptsBefore);
  });

  test('allows the day right after the last presence in the origin', () async {
    await world.session(dayOfMonth: 8);

    ok(await moveOn(9));

    expect((await world.groups.byId(origin))!.memberships.single.to, day(8));
  });

  test('refuses a date on the day of the last presence', () async {
    await world.session(dayOfMonth: 8);

    expect(codeOf(await moveOn(8)), InvariantCode.moveBeforeLastPresence);
  });

  test('refuses a date before the last presence', () async {
    await world.session(dayOfMonth: 8);

    expect(codeOf(await moveOn(5)), InvariantCode.moveBeforeLastPresence);
  });

  test('ignores sessions where the student was absent', () async {
    await world.session(dayOfMonth: 8, present: const {});

    ok(await moveOn(5));
  });

  test('refuses a date not after the start of the membership', () async {
    expect(codeOf(await moveOn(1)), InvariantCode.moveBeforeLastPresence);
  });

  test('refuses a date after the end of the season', () async {
    final result = await move(
      studentId: s1,
      toGroupId: target,
      on: DateTime(2026, 11),
    );

    expect(codeOf(result), InvariantCode.seasonOutsidePeriod);
  });

  test('refuses a target of another audience', () async {
    await addGroup('adults', audience: Audience.adults);

    expect(
      codeOf(await moveOn(10, to: const GroupId('adults'))),
      InvariantCode.audienceMismatch,
    );
  });

  test('refuses a target of another season', () async {
    await addGroup('later', season: 'other');

    expect(
      codeOf(await moveOn(10, to: const GroupId('later'))),
      InvariantCode.unknownGroup,
    );
  });

  test('refuses the group the student already belongs to', () async {
    expect(
      codeOf(await moveOn(10, to: origin)),
      InvariantCode.membershipAlreadyOpen,
    );
  });

  group('a student who belongs to no group', () {
    setUp(() async {
      final group = (await world.groups.byId(origin))!;
      await world.groups.save(group.release(studentId: s1, to: day(5)));
    });

    test('is placed in the chosen group from the given day', () async {
      final destination = ok(await moveOn(10));

      expect(destination.id, target);
      expect(destination.isMemberOn(s1, day(9)), isFalse);
      expect(destination.isMemberOn(s1, day(10)), isTrue);
      expect((await world.groups.byId(origin))!.memberships.single.to, day(5));
    });

    test('cannot be placed before the end of their last membership', () async {
      expect(codeOf(await moveOn(5)), InvariantCode.moveBeforeLastPresence);
      ok(await moveOn(6));
    });

    test('cannot be placed in a group of another audience', () async {
      await addGroup('adults', audience: Audience.adults);

      expect(
        codeOf(await moveOn(10, to: const GroupId('adults'))),
        InvariantCode.audienceMismatch,
      );
    });

    test('may leave behind an open membership of a closed season', () async {
      await world.seasons.save(
        (await world.seasons.byId(const SeasonId('season')))!
            .copyWith(closedOn: day(8)),
      );
      await world.seasons.save(
        Season(
          id: const SeasonId('other'),
          label: '2026-2027 (2)',
          startDate: day(9),
          endDate: DateTime(2027, 8, 31),
        ),
      );
      await addGroup('later', season: 'other');
      // L'élève n'a pas quitté g1 (clôture sans reconduction).
      final g1 = (await world.groups.byId(origin))!;
      await world.groups.save(
        g1.copyWith(
          memberships: [Membership(studentId: s1, from: day(1))],
        ),
      );

      final placed = ok(await moveOn(10, to: const GroupId('later')));

      expect(placed.isMemberOn(s1, day(10)), isTrue);
    });

    test('is refused once the season is closed', () async {
      await world.seasons.save(
        (await world.seasons.byId(const SeasonId('season')))!
            .copyWith(closedOn: day(8)),
      );

      expect(codeOf(await moveOn(10)), InvariantCode.seasonClosed);
    });
  });

  test('refuses an unknown student, group or target', () async {
    expect(
      err(
        await move(
          studentId: const StudentId('ghost'),
          toGroupId: target,
          on: day(10),
        ),
      ),
      isA<NotFound>(),
    );
    expect(err(await moveOn(10, to: const GroupId('ghost'))), isA<NotFound>());
  });

  test('writes nothing when the target cannot be saved', () async {
    final failing = MoveStudent(
      world.students,
      _FailingOnSave(world.groups, fail: target),
      world.seasons,
      world.sessions,
      InMemoryUnitOfWork(),
    );

    await expectLater(
      failing(studentId: s1, toGroupId: target, on: day(10)),
      throwsStateError,
    );

    expect((await world.groups.byId(origin))!.memberships.single.to, isNull);
  });
}

/// Dépôt de groupes dont l'écriture de [fail] échoue (tout ou rien).
class _FailingOnSave implements GroupRepository {
  _FailingOnSave(this._inner, {required this.fail});

  final GroupRepository _inner;
  final GroupId fail;

  @override
  Future<void> save(Group group) async {
    if (group.id == fail) throw StateError('écriture impossible');
    await _inner.save(group);
  }

  @override
  Future<Group?> byId(GroupId id) => _inner.byId(id);

  @override
  Future<List<Group>> all() => _inner.all();

  @override
  Future<void> delete(GroupId id) => _inner.delete(id);

  @override
  Future<void> eraseStudent(StudentId studentId) =>
      _inner.eraseStudent(studentId);

  @override
  Future<Set<GroupId>> idsEverContaining(StudentId studentId) =>
      _inner.idsEverContaining(studentId);

  @override
  Stream<List<Group>> watchAll() => _inner.watchAll();

  @override
  Stream<Group?> watchById(GroupId id) => _inner.watchById(id);
}
