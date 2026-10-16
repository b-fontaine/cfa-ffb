import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/track_group/domain/group_attendance.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

const _group = GroupId('g1');

/// Groupe `g1` : s1 et s2 membres depuis le 1er, s3 selon `s3From` et `s3To`.
Group group({int? s3From, int? s3To}) {
  var result = Group(
    id: _group,
    seasonId: const SeasonId('season'),
    name: 'Jeunes',
    audience: Audience.children,
  );
  for (final name in ['s1', 's2']) {
    result = result.admit(
      studentId: StudentId(name),
      studentAudience: Audience.children,
      from: day(1),
    );
  }
  if (s3From != null) {
    result = result.admit(
      studentId: const StudentId('s3'),
      studentAudience: Audience.children,
      from: day(s3From),
    );
    if (s3To != null) {
      result = result.release(studentId: const StudentId('s3'), to: day(s3To));
    }
  }
  return result;
}

SessionRecord session(
  int dayOfMonth,
  Set<String> present, {
  GroupId groupId = _group,
}) => SessionRecord(
  id: SessionId('x$dayOfMonth-${groupId.value}'),
  groupId: groupId,
  seasonId: const SeasonId('season'),
  date: day(dayOfMonth),
  audience: Audience.children,
  present: {for (final name in present) StudentId(name)},
);

GroupAttendance attendance(
  List<SessionRecord> sessions, {
  Group? of,
  int asOf = 20,
}) =>
    groupAttendance(sessions: sessions, group: of ?? group(), asOf: day(asOf));

void main() {
  test('counts the present members over the possible ones', () {
    final result = attendance([
      session(3, {'s1', 's2'}),
      session(10, {'s1'}),
    ]);

    expect(result.present, 3);
    expect(result.possible, 4);
    expect(result.sessionCount, 2);
    expect(result.percent, 75);
    expect(result.isEmpty, isFalse);
  });

  test('rounds the percentage to the nearest integer', () {
    final result = attendance([
      session(3, {'s1', 's2'}),
      session(4, {'s1', 's2'}),
      session(5, {'s1'}),
    ]);

    // 5 présences sur 6 possibles : 83,3 %.
    expect(result.percent, 83);
  });

  test(
    'counts the attendance of each member over the sessions he belonged to',
    () {
      final result = attendance([
        session(5, {'s1', 's2', 's3'}),
        session(12, {'s1', 's3'}),
      ], of: group(s3From: 8));

      expect(result.members[const StudentId('s1')]!.attended, 2);
      expect(result.members[const StudentId('s1')]!.total, 2);
      expect(result.members[const StudentId('s2')]!.attended, 1);
      expect(result.members[const StudentId('s2')]!.total, 2);
      // s3 n'est membre qu'à partir du 8 : seule la séance du 12 compte.
      expect(result.members[const StudentId('s3')]!.attended, 1);
      expect(result.members[const StudentId('s3')]!.total, 1);
    },
  );

  test('a member without any session counted has an empty attendance', () {
    final result = attendance([
      session(5, {'s1'}),
    ], of: group(s3From: 8));

    expect(result.members[const StudentId('s3')]!.total, 0);
    expect(result.members[const StudentId('s3')]!.isEmpty, isTrue);
  });

  test('a group without session has no percentage, not 0 %', () {
    final result = attendance([]);

    expect(result.isEmpty, isTrue);
    expect(result.sessionCount, 0);
    expect(result.percent, isNull);
  });

  test('does not penalise a student who joined later', () {
    final result = attendance([
      session(5, {'s1', 's2'}),
      session(12, {'s1', 's2', 's3'}),
    ], of: group(s3From: 10));

    // Séance du 5 : 2 possibles ; séance du 12 : 3 possibles.
    expect(result.possible, 5);
    expect(result.present, 5);
    expect(result.percent, 100);
  });

  test('counts a former member for the sessions he belonged to only', () {
    final result = attendance([
      session(5, {'s1', 's2', 's3'}),
      session(12, {'s1', 's2'}),
    ], of: group(s3From: 2, s3To: 8));

    // Séance du 5 : 3 possibles ; séance du 12 : s3 n'est plus membre.
    expect(result.possible, 5);
    expect(result.present, 5);
  });

  test('ignores a present student who was not a member at the date', () {
    final result = attendance([
      session(5, {'s1', 's3'}),
    ], of: group(s3From: 10));

    expect(result.possible, 2);
    expect(result.present, 1);
  });

  test('ignores a session dated after the as-of day', () {
    final result = attendance([
      session(10, {'s1', 's2'}),
      session(21, {'s1'}),
    ]);

    expect(result.sessionCount, 1);
    expect(result.possible, 2);
  });

  test('keeps a session dated the as-of day, whatever its hour', () {
    final result = groupAttendance(
      sessions: [
        session(20, {'s1', 's2'}),
      ],
      group: group(),
      asOf: DateTime(2026, 10, 20, 9, 30),
    );

    expect(result.sessionCount, 1);
  });

  test('ignores the sessions of another group', () {
    final result = attendance([
      session(10, {'s1', 's2'}),
      session(11, {'s1'}, groupId: const GroupId('autre')),
    ]);

    expect(result.sessionCount, 1);
    expect(result.possible, 2);
  });

  test('lists the latest sessions first, at most five', () {
    final result = attendance([
      for (var d = 2; d <= 8; d++) session(d, {'s1', 's2'}),
    ]);

    expect(result.sessionCount, 7);
    expect(result.recent, hasLength(5));
    expect(result.recent.map((s) => s.date), [
      day(8),
      day(7),
      day(6),
      day(5),
      day(4),
    ]);
    expect(result.recent.first.present, 2);
    expect(result.recent.first.possible, 2);
  });
}
