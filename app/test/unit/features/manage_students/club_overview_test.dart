import 'package:billard_cfa/features/manage_students/domain/club_overview.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/club_fixtures.dart';

void main() {
  test('eligible groups keep only the groups that have members', () {
    final full = groupOverview('g1', 'Full', [summary('s1', 'Léa')]);
    final empty = groupOverview('g2', 'Empty', []);
    final club = ClubOverview(groups: [empty, full], unassigned: const []);

    expect(club.eligibleGroups, [full]);
  });

  test('eligible groups are empty when no group has members', () {
    final club = ClubOverview(
      groups: [groupOverview('g2', 'Empty', [])],
      unassigned: const [],
    );

    expect(club.eligibleGroups, isEmpty);
  });
}
