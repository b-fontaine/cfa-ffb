import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/features/change_audience/domain/list_destination_groups.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late ListDestinationGroups list;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
    for (final (id, season) in [
      ('ga1', 'season'),
      ('ga2', 'season'),
      ('gx', 'old'),
    ]) {
      await world.groups.save(
        Group(
          id: GroupId(id),
          seasonId: SeasonId(season),
          name: id,
          audience: Audience.adults,
        ),
      );
    }
    list = ListDestinationGroups(world.groups, world.seasons);
  });

  test(
    'lists the groups of the target audience in the season of the student',
    () async {
      final choices = ok(
        await list(
          studentId: const StudentId('s1'),
          audience: Audience.adults,
          today: day(12),
        ),
      );

      expect(choices, [
        const GroupChoice(GroupId('ga1'), 'ga1'),
        const GroupChoice(GroupId('ga2'), 'ga2'),
      ]);
    },
  );

  test('falls back to the open season for a student without group', () async {
    final group = (await world.groups.byId(const GroupId('g1')))!;
    await world.groups.save(
      group.release(studentId: const StudentId('s1'), to: day(5)),
    );

    final choices = ok(
      await list(
        studentId: const StudentId('s1'),
        audience: Audience.adults,
        today: day(12),
      ),
    );

    expect(choices.map((c) => c.id.value), ['ga1', 'ga2']);
  });
}
