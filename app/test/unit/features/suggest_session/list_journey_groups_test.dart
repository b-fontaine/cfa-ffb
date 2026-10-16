import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/suggest_session/domain/list_journey_groups.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixed_clock.dart';

void main() {
  late DomainWorld world;
  late ListJourneyGroups list;

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
    list = ListJourneyGroups(
      world.groups,
      world.seasons,
      FixedClock(DateTime(2026, 10, 12)),
    );
  });

  test('offers the groups of the current season with their name', () async {
    await world.groups.save(
      Group(
        id: const GroupId('empty'),
        seasonId: const SeasonId('season'),
        name: 'Vide',
        audience: Audience.adults,
      ),
    );

    final choices = ok(await list());

    expect(choices.map((choice) => choice.id), [
      const GroupId('g1'),
      const GroupId('empty'),
    ]);
    expect(choices.last, const GroupChoice(GroupId('empty'), 'Vide'));
  });

  test('falls back to every group when no season contains today', () async {
    final later = ListJourneyGroups(
      world.groups,
      world.seasons,
      FixedClock(DateTime(2027, 8)),
    );

    final choices = ok(await later());

    expect(choices.map((choice) => choice.id), [
      const GroupId('g1'),
      const GroupId('old-group'),
    ]);
  });
}
