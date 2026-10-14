import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/plan_session/domain/list_plannable_groups.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

void main() {
  late DomainWorld world;
  late ListPlannableGroups list;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub();
    await world.seasons.save(
      Season(
        id: const SeasonId('old'),
        label: '2025-2026',
        startDate: DateTime(2025, 9),
        endDate: DateTime(2026, 6, 30),
      ),
    );
    await world.groups.save(
      Group(
        id: const GroupId('old-group'),
        seasonId: const SeasonId('old'),
        name: 'Ancien',
        audience: Audience.adults,
      ),
    );
    list = ListPlannableGroups(world.groups, world.seasons);
  });

  test(
    'keeps the groups of the current season, even without members',
    () async {
      await world.groups.save(
        Group(
          id: const GroupId('empty'),
          seasonId: const SeasonId('season'),
          name: 'Vide',
          audience: Audience.adults,
        ),
      );

      final groups = await list(today: day(12));

      expect(groups.map((g) => g.id), [
        const GroupId('g1'),
        const GroupId('empty'),
      ]);
    },
  );

  test('keeps the season up to its last day, then falls back', () async {
    final lastDay = await list(today: day(31));
    final dayAfter = await list(today: DateTime(2026, 11));

    expect(lastDay.map((g) => g.id), [const GroupId('g1')]);
    expect(dayAfter.map((g) => g.id), [
      const GroupId('g1'),
      const GroupId('old-group'),
    ]);
  });

  test('falls back to every group when no season contains today', () async {
    final groups = await list(today: DateTime(2027, 8));

    expect(groups.map((g) => g.id), [
      const GroupId('g1'),
      const GroupId('old-group'),
    ]);
  });
}
