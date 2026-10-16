import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/features/manage_students/domain/list_enrollment_groups.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late ListEnrollmentGroups list;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
    list = ListEnrollmentGroups(world.groups, world.seasons);
  });

  test('lists the groups of the audience in the open season', () async {
    await world.groups.save(
      Group(
        id: const GroupId('g2'),
        seasonId: const SeasonId('season'),
        name: 'Mercredi',
        audience: Audience.children,
      ),
    );
    await world.groups.save(
      Group(
        id: const GroupId('ga'),
        seasonId: const SeasonId('season'),
        name: 'Soir',
        audience: Audience.adults,
      ),
    );

    final choices = ok(await list(audience: Audience.children, today: day(12)));

    expect(choices, [
      const GroupChoice(GroupId('g1'), 'Groupe'),
      const GroupChoice(GroupId('g2'), 'Mercredi'),
    ]);
  });

  test('lists nothing when no season is open', () async {
    final choices = ok(
      await list(audience: Audience.children, today: DateTime(2027)),
    );

    expect(choices, isEmpty);
  });

  test('lists nothing for a closed season', () async {
    await world.seasons.save(
      (await world.seasons.byId(const SeasonId('season')))!
          .copyWith(closedOn: day(10)),
    );

    expect(
      ok(await list(audience: Audience.children, today: day(12))),
      isEmpty,
    );
  });
}
