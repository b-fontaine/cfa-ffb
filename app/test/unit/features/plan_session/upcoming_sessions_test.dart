import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/features/plan_session/domain/upcoming_sessions.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

void main() {
  final today = day(12);
  final group = Group(
    id: const GroupId('g1'),
    seasonId: const SeasonId('season'),
    name: 'Jeunes',
    audience: Audience.children,
  );

  PlannedSessionSummary planned(
    String id,
    int dayOfMonth, {
    bool recorded = false,
    bool withGroup = true,
    bool groupGone = false,
    SheetId? sheet,
  }) => PlannedSessionSummary(
    session: Session(
      id: id,
      title: id,
      date: day(dayOfMonth),
      audience: Audience.children,
      groupId: withGroup ? const GroupId('g1') : null,
      sheetId: sheet,
    ),
    group: withGroup && !groupGone ? group : null,
    recordId: recorded ? SessionId('x-$id') : null,
  );

  List<String> ids(List<PlannedSessionSummary> list) => [
    for (final s in list) s.session.id,
  ];

  test('has nothing when nothing is planned', () {
    final upcoming = upcomingOf(const [], today);

    expect(upcoming.next, isNull);
    expect(upcoming.sameDayOthers, 0);
    expect(upcoming.toRecord, isEmpty);
  });

  test('takes the first session from today on, in the given order', () {
    final upcoming = upcomingOf([
      planned('past', 5),
      planned('soon', 14),
      planned('late', 20),
    ], today);

    expect(upcoming.next?.session.id, 'soon');
  });

  test('a session dated today without record is the next one', () {
    final upcoming = upcomingOf([planned('today', 12)], today);

    expect(upcoming.next?.session.id, 'today');
  });

  test('a session dated today with a record is no longer proposed', () {
    final upcoming = upcomingOf([
      planned('today', 12, recorded: true),
      planned('later', 14),
    ], today);

    expect(upcoming.next?.session.id, 'later');
  });

  test('counts the other sessions of the same day', () {
    final upcoming = upcomingOf([
      planned('first', 14),
      planned('second', 14),
      planned('third', 14),
      planned('other-day', 16),
    ], today);

    expect(upcoming.next?.session.id, 'first');
    expect(upcoming.sameDayOthers, 2);
  });

  test('a session without group can be next', () {
    final upcoming = upcomingOf([planned('free', 14, withGroup: false)], today);

    expect(upcoming.next?.session.id, 'free');
  });

  test('to record: past sessions with a group, no record, within 7 days', () {
    final upcoming = upcomingOf([
      planned('too-old', 4),
      planned('edge', 5),
      planned('recent', 10),
      planned('recorded', 9, recorded: true),
      planned('no-group', 8, withGroup: false),
      planned('group-gone', 7, groupGone: true),
      planned('future', 13),
    ], today);

    expect(ids(upcoming.toRecord), ['recent', 'edge']);
  });

  test('to record keeps the most recent three', () {
    final upcoming = upcomingOf([
      planned('a', 6),
      planned('b', 7),
      planned('c', 8),
      planned('d', 9),
      planned('e', 10),
    ], today);

    expect(ids(upcoming.toRecord), ['e', 'd', 'c']);
  });

  test('a session dated today is never to record', () {
    final upcoming = upcomingOf([planned('today', 12)], today);

    expect(upcoming.toRecord, isEmpty);
  });

  test('carries the group names given', () {
    final upcoming = upcomingOf(
      const [],
      today,
      groupNames: {const GroupId('g1'): 'Jeunes'},
    );

    expect(upcoming.groupNames[const GroupId('g1')], 'Jeunes');
  });

  test('ignores the time of the day of today', () {
    final upcoming = upcomingOf([
      planned('today', 12),
    ], DateTime(2026, 10, 12, 23));

    expect(upcoming.next?.session.id, 'today');
  });
}
