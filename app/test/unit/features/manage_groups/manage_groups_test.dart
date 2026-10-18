import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/manage_groups/domain/create_group.dart';
import 'package:billard_cfa/features/manage_groups/domain/delete_group.dart';
import 'package:billard_cfa/features/manage_groups/domain/rename_group.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late CreateGroup create;
  late RenameGroup rename;
  late DeleteGroup delete;

  const season = SeasonId('season');

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
    create = CreateGroup(world.groups, world.seasons, world.ids);
    rename = RenameGroup(world.groups);
    delete = DeleteGroup(world.groups, world.sessions, world.plannedSessions);
  });

  group('CreateGroup', () {
    test('creates a second group for the same audience', () async {
      final created = ok(
        await create(
          seasonId: season,
          name: 'Mercredi',
          audience: Audience.children,
        ),
      );

      expect(created.name, 'Mercredi');
      expect(created.audience, Audience.children);
      expect(created.seasonId, season);
      expect(created.memberships, isEmpty);
      expect(await world.groups.all(), hasLength(2));
    });

    test('trims the name', () async {
      final created = ok(
        await create(
          seasonId: season,
          name: '  Mercredi ',
          audience: Audience.children,
        ),
      );

      expect(created.name, 'Mercredi');
    });

    test('refuses a name already used in the season, case aside', () async {
      final result = await create(
        seasonId: season,
        name: ' GROUPE ',
        audience: Audience.adults,
      );

      expect(codeOf(result), InvariantCode.groupNameTaken);
      expect(await world.groups.all(), hasLength(1));
    });

    test('allows the name of a group of another season', () async {
      await world.seasons.save(
        (await world.seasons.byId(season))!.copyWith(
          id: const SeasonId('other'),
          label: '2027-2028',
          startDate: DateTime(2027, 9),
          endDate: DateTime(2028, 8, 31),
        ),
      );

      final created = ok(
        await create(
          seasonId: const SeasonId('other'),
          name: 'Groupe',
          audience: Audience.children,
        ),
      );

      expect(created.seasonId, const SeasonId('other'));
    });

    test('refuses a blank name', () async {
      final result = await create(
        seasonId: season,
        name: ' ',
        audience: Audience.children,
      );

      expect(codeOf(result), InvariantCode.blankName);
    });

    test('refuses a name longer than the rules accept', () async {
      final result = await create(
        seasonId: season,
        name: 'a' * 81,
        audience: Audience.children,
      );

      expect(codeOf(result), InvariantCode.nameTooLong);
    });

    test('refuses an unknown season', () async {
      final result = await create(
        seasonId: const SeasonId('ghost'),
        name: 'Mercredi',
        audience: Audience.children,
      );

      expect(err(result), isA<NotFound>());
    });
  });

  group('RenameGroup', () {
    test('renames and persists', () async {
      final renamed = ok(
        await rename(groupId: const GroupId('g1'), name: 'Lundi'),
      );

      expect(renamed.name, 'Lundi');
      expect((await world.groups.byId(const GroupId('g1')))!.name, 'Lundi');
      expect(renamed.memberships, hasLength(1));
    });

    test('accepts the group own name with another case', () async {
      final renamed = ok(
        await rename(groupId: const GroupId('g1'), name: 'GROUPE'),
      );

      expect(renamed.name, 'GROUPE');
    });

    test('refuses a name used by another group of the season', () async {
      ok(
        await create(
          seasonId: season,
          name: 'Mercredi',
          audience: Audience.children,
        ),
      );

      final result = await rename(
        groupId: const GroupId('g1'),
        name: ' mercredi',
      );

      expect(codeOf(result), InvariantCode.groupNameTaken);
      expect((await world.groups.byId(const GroupId('g1')))!.name, 'Groupe');
    });

    test('refuses an unknown group', () async {
      expect(
        err(await rename(groupId: const GroupId('ghost'), name: 'X')),
        isA<NotFound>(),
      );
    });
  });

  group('DeleteGroup', () {
    Future<Result<void>> deleteAt(String id, [int dayOfMonth = 12]) =>
        delete(groupId: GroupId(id), today: day(dayOfMonth));

    test('refuses a group that still has a member', () async {
      expect(codeOf(await deleteAt('g1')), InvariantCode.groupNotEmpty);
      expect(await world.groups.byId(const GroupId('g1')), isNotNull);
    });

    test('refuses a group whose member has not left yet', () async {
      final group = (await world.groups.byId(const GroupId('g1')))!;
      await world.groups.save(
        group.release(studentId: const StudentId('s1'), to: day(20)),
      );

      expect(codeOf(await deleteAt('g1')), InvariantCode.groupNotEmpty);
    });

    test('deletes an empty group without any session', () async {
      final empty = ok(
        await create(
          seasonId: season,
          name: 'Mercredi',
          audience: Audience.children,
        ),
      );

      ok(await deleteAt(empty.id.value));

      expect(await world.groups.byId(empty.id), isNull);
      expect(await world.groups.all(), hasLength(1));
    });

    test('deletes a group whose members all left before today', () async {
      final group = (await world.groups.byId(const GroupId('g1')))!;
      await world.groups.save(
        group.release(studentId: const StudentId('s1'), to: day(5)),
      );

      ok(await deleteAt('g1'));

      expect(await world.groups.byId(const GroupId('g1')), isNull);
    });

    test('refuses an empty group that holds a recorded session', () async {
      await world.session();
      final group = (await world.groups.byId(const GroupId('g1')))!;
      await world.groups.save(
        group.release(studentId: const StudentId('s1'), to: day(5)),
      );

      expect(codeOf(await deleteAt('g1')), InvariantCode.groupHasRecords);
      expect(await world.groups.byId(const GroupId('g1')), isNotNull);
    });

    test('refuses an empty group that a planned session targets', () async {
      await world.plannedSessions.add(
        Session(
          id: 'p1',
          title: 'Posture',
          date: day(19),
          audience: Audience.children,
          groupId: const GroupId('g1'),
        ),
      );
      final group = (await world.groups.byId(const GroupId('g1')))!;
      await world.groups.save(
        group.release(studentId: const StudentId('s1'), to: day(5)),
      );

      expect(codeOf(await deleteAt('g1')), InvariantCode.groupHasPlanned);
      expect(await world.groups.byId(const GroupId('g1')), isNotNull);
    });

    test('ignores a planned session of another group or of none', () async {
      final other = ok(
        await create(
          seasonId: season,
          name: 'Mercredi',
          audience: Audience.children,
        ),
      );
      await world.plannedSessions.add(
        Session(
          id: 'p1',
          title: 'Posture',
          date: day(19),
          audience: Audience.children,
          groupId: const GroupId('g1'),
        ),
      );
      await world.plannedSessions.add(
        Session(
          id: 'p2',
          title: 'Libre',
          date: day(20),
          audience: Audience.children,
        ),
      );

      ok(await deleteAt(other.id.value));

      expect(await world.groups.byId(other.id), isNull);
    });

    test('refuses an unknown group', () async {
      expect(err(await deleteAt('ghost')), isA<NotFound>());
    });
  });
}
