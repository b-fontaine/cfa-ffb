import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/close_season/domain/planned_after_closure.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

final _season = Season(
  id: const SeasonId('season'),
  label: '2026-2027',
  startDate: day(1),
  endDate: day(31),
);

const _group = GroupId('g1');

Session _planned(String id, int dayOfMonth, {GroupId? group = _group}) =>
    Session(
      id: id,
      title: id,
      date: DateTime(2026, 10, dayOfMonth, 18),
      audience: Audience.children,
      groupId: group,
    );

List<String> _ids(Iterable<Session> sessions) => [
  for (final session in sessions) session.id,
];

void main() {
  test('selects the planned sessions of the season after the closing day', () {
    final result = plannedAfterClosure(
      season: _season,
      groupIds: {_group},
      planned: [_planned('same-day', 12), _planned('later', 13)],
      day: day(12),
    );

    expect(_ids(result), ['later']);
  });

  test('a session without group counts when its date is in the season', () {
    final result = plannedAfterClosure(
      season: _season,
      groupIds: {_group},
      planned: [
        _planned('inside', 20, group: null),
        Session(
          id: 'outside',
          title: 'outside',
          date: DateTime(2026, 11, 20),
          audience: Audience.children,
        ),
      ],
      day: day(12),
    );

    expect(_ids(result), ['inside']);
  });

  test('ignores the sessions of the groups of another season', () {
    final result = plannedAfterClosure(
      season: _season,
      groupIds: {_group},
      planned: [_planned('elsewhere', 20, group: const GroupId('other'))],
      day: day(12),
    );

    expect(result, isEmpty);
  });
}
