import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/track_progress/domain/attendance.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

const _s1 = StudentId('s1');
const _s2 = StudentId('s2');

SessionRecord _session(
  String id, {
  required int dayOfMonth,
  required Set<StudentId> present,
  String group = 'g1',
}) => SessionRecord(
  id: SessionId(id),
  groupId: GroupId(group),
  seasonId: const SeasonId('season'),
  date: day(dayOfMonth),
  audience: Audience.children,
  present: present,
);

/// `g1` : `s1` membre depuis le 1er, `s2` du 5 au 8 ; `g2` sans membre.
final _groups = [
  Group(
    id: const GroupId('g1'),
    seasonId: const SeasonId('season'),
    name: 'Jeunes',
    audience: Audience.children,
    memberships: [
      Membership(studentId: _s1, from: day(1)),
      Membership(studentId: _s2, from: day(5), to: day(8)),
    ],
  ),
  Group(
    id: const GroupId('g2'),
    seasonId: const SeasonId('season'),
    name: 'Autres',
    audience: Audience.children,
  ),
];

final List<SessionRecord> _sessions = [
  _session('x1', dayOfMonth: 2, present: {_s1}),
  _session('x2', dayOfMonth: 6, present: {_s1, _s2}),
  _session('x3', dayOfMonth: 10, present: {_s2}),
  _session('y1', dayOfMonth: 3, present: const {}, group: 'g2'),
];

void main() {
  test('counts the group sessions since the membership started', () async {
    final attendance = attendanceOf(
      studentId: _s1,
      sessions: _sessions,
      groups: _groups,
    );

    expect(attendance, const Attendance(attended: 2, total: 3));
  });

  test('ignores the sessions outside the membership period', () async {
    final attendance = attendanceOf(
      studentId: _s2,
      sessions: _sessions,
      groups: _groups,
    );

    expect(attendance, const Attendance(attended: 1, total: 1));
  });

  test('is empty for a student without any group', () async {
    final attendance = attendanceOf(
      studentId: const StudentId('s3'),
      sessions: _sessions,
      groups: _groups,
    );

    expect(attendance, const Attendance(attended: 0, total: 0));
    expect(attendance.isEmpty, isTrue);
  });

  test('ignores the sessions of a group the student never joined', () async {
    final attendance = attendanceOf(
      studentId: _s1,
      sessions: [
        _session('y2', dayOfMonth: 4, present: {_s1}, group: 'g2'),
      ],
      groups: _groups,
    );

    expect(attendance, const Attendance(attended: 0, total: 0));
  });
}
