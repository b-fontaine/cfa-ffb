import 'package:billard_cfa/entities/group/domain/current_groups.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

Group _group(String id, String season) => Group(
  id: GroupId(id),
  seasonId: SeasonId(season),
  name: id,
  audience: Audience.children,
);

void main() {
  final groups = [_group('old', 'past'), _group('g1', 'now')];

  test('keeps the groups of the current seasons', () {
    final current = currentGroups(
      groups,
      currentSeasons: {const SeasonId('now')},
    );

    expect(current.map((g) => g.id), [const GroupId('g1')]);
  });

  test('falls back to every group without a current season', () {
    expect(currentGroups(groups, currentSeasons: const {}), groups);
  });

  test('is unmodifiable', () {
    expect(
      () => currentGroups(groups, currentSeasons: const {}).clear(),
      throwsUnsupportedError,
    );
  });

  test('never returns the groups of a closed season', () {
    final current = currentGroups(
      groups,
      currentSeasons: const {},
      closedSeasons: {const SeasonId('past')},
    );

    expect(current.map((g) => g.id), [const GroupId('g1')]);
  });

  test('a closed season is excluded even when it is listed as current', () {
    final current = currentGroups(
      groups,
      currentSeasons: {const SeasonId('now'), const SeasonId('past')},
      closedSeasons: {const SeasonId('past')},
    );

    expect(current.map((g) => g.id), [const GroupId('g1')]);
  });
}
