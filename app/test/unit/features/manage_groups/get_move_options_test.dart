import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/manage_groups/domain/get_move_options.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late GetMoveOptions options;

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
    options = GetMoveOptions(world.students, world.groups, world.seasons);
  });

  test('offers the other groups of the same season and audience', () async {
    await addGroup('g2');
    await addGroup('adults', audience: Audience.adults);
    await addGroup('later', season: 'other');

    final result = ok(
      await options(studentId: const StudentId('s1'), today: day(12)),
    );

    expect(result.firstName, 's1');
    expect(result.current, const GroupChoice(GroupId('g1'), 'Groupe'));
    expect(result.destinations, [
      const GroupChoice(GroupId('g2'), 'Groupe g2'),
    ]);
  });

  test('offers nothing when the group is alone', () async {
    final result = ok(
      await options(studentId: const StudentId('s1'), today: day(12)),
    );

    expect(result.destinations, isEmpty);
  });

  test(
    'a student without group may join any group of the open season',
    () async {
      await addGroup('g2');
      final group = (await world.groups.byId(const GroupId('g1')))!;
      await world.groups.save(
        group.release(studentId: const StudentId('s1'), to: day(5)),
      );

      final result = ok(
        await options(studentId: const StudentId('s1'), today: day(12)),
      );

      expect(result.current, isNull);
      expect(result.destinations.map((g) => g.id.value), ['g1', 'g2']);
    },
  );

  test('ignores a membership left open in a closed season', () async {
    await addGroup('g2');
    await world.seasons.save(
      (await world.seasons.byId(const SeasonId('season')))!
          .copyWith(closedOn: day(8)),
    );
    await world.seasons.save(
      Season(
        id: const SeasonId('other'),
        label: 'suite',
        startDate: day(9),
        endDate: DateTime(2027, 8, 31),
      ),
    );
    await addGroup('later', season: 'other');

    final result = ok(
      await options(studentId: const StudentId('s1'), today: day(12)),
    );

    expect(result.current, isNull);
    expect(result.destinations.map((g) => g.id.value), ['later']);
  });

  test('refuses an unknown student', () async {
    expect(
      err(await options(studentId: const StudentId('ghost'), today: day(12))),
      isA<NotFound>(),
    );
  });
}
