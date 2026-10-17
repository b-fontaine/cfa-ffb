import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/data/in_memory_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/features/export_sheet/domain/list_export_groups.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixed_clock.dart';

void main() {
  test('lists the groups of the current season in their saved order', () async {
    final seasons = InMemorySeasonRepository();
    final groups = InMemoryGroupRepository();
    await seasons.save(
      Season(
        id: const SeasonId('now'),
        label: '2026-2027',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2027, 6, 30),
      ),
    );
    await seasons.save(
      Season(
        id: const SeasonId('old'),
        label: '2025-2026',
        startDate: DateTime(2025, 9),
        endDate: DateTime(2026, 6, 30),
      ),
    );
    for (final (id, season, name) in [
      ('g1', 'now', 'Mardi'),
      ('g2', 'now', 'Jeudi'),
      ('g3', 'old', 'Ancien'),
    ]) {
      await groups.save(
        Group(
          id: GroupId(id),
          seasonId: SeasonId(season),
          name: name,
          audience: Audience.children,
        ),
      );
    }

    final result = await ListExportGroups(
      groups,
      seasons,
      FixedClock(DateTime(2026, 10, 12)),
    )();

    expect((result as Ok<List<GroupChoice>>).value, [
      const GroupChoice(GroupId('g1'), 'Mardi'),
      const GroupChoice(GroupId('g2'), 'Jeudi'),
    ]);
  });
}
