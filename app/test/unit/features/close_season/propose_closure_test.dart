import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/close_season/domain/closure_proposal.dart';
import 'package:billard_cfa/features/close_season/domain/propose_closure.dart';
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

Student _student(String id, {int enrolledOn = 1, int month = 10}) =>
    Student.enroll(
      id: StudentId(id),
      firstName: id,
      audience: Audience.children,
      since: DateTime(2026, month, enrolledOn),
    );

Group _group(List<String> members, {String season = 'season'}) {
  var group = Group(
    id: const GroupId('g1'),
    seasonId: SeasonId(season),
    name: 'Jeunes',
    audience: Audience.children,
  );
  for (final member in members) {
    group = group.admit(
      studentId: StudentId(member),
      studentAudience: Audience.children,
      from: day(1),
    );
  }
  return group;
}

SessionRecord _session(List<String> present, {String season = 'season'}) =>
    SessionRecord(
      id: SessionId('x-${present.join()}-$season'),
      groupId: const GroupId('g1'),
      seasonId: SeasonId(season),
      date: day(5),
      audience: Audience.children,
      present: {for (final p in present) StudentId(p)},
    );

Season _otherSeason({bool closed = false}) => Season(
  id: const SeasonId('other'),
  label: '2025-2026',
  startDate: DateTime(2025, 9),
  endDate: DateTime(2026, 8, 31),
  closedOn: closed ? DateTime(2026, 6) : null,
);

Map<String, ClosureProposal> _propose({
  required List<Student> students,
  required List<Group> groups,
  List<SessionRecord> sessions = const [],
  List<Season> others = const [],
}) => {
  for (final p in proposeClosure(
    season: _season,
    seasons: [_season, ...others],
    students: students,
    groups: groups,
    sessions: sessions,
  ))
    p.studentId.value: p,
};

void main() {
  test('proposes to keep an active student enrolled this season', () {
    final result = _propose(
      students: [_student('a')],
      groups: [
        _group(['a']),
      ],
      sessions: [
        _session(['a']),
      ],
    );

    expect(result['a']!.choice, ClosureChoice.keep);
    expect(result['a']!.reason, ClosureReason.carriedOver);
    expect(result['a']!.firstName, 'a');
  });

  test('proposes to erase a student absent from every session', () {
    final result = _propose(
      students: [_student('a')],
      groups: [
        _group(['a']),
      ],
    );

    expect(result['a']!.choice, ClosureChoice.erase);
    expect(result['a']!.reason, ClosureReason.inactive);
  });

  test('only the sessions of the season make a student active', () {
    final result = _propose(
      students: [_student('a')],
      groups: [
        _group(['a']),
      ],
      sessions: [
        _session(['a'], season: 'other'),
      ],
    );

    expect(result['a']!.reason, ClosureReason.inactive);
  });

  test('proposes to erase a student enrolled before the season', () {
    final result = _propose(
      students: [_student('a', enrolledOn: 15, month: 9)],
      groups: [
        _group(['a']),
      ],
      sessions: [
        _session(['a']),
      ],
    );

    expect(result['a']!.choice, ClosureChoice.erase);
    expect(result['a']!.reason, ClosureReason.retentionExpired);
  });

  test('a student enrolled on the first day of the season is kept', () {
    final result = _propose(
      students: [_student('a')],
      groups: [
        _group(['a']),
      ],
      sessions: [
        _session(['a']),
      ],
    );

    expect(result['a']!.choice, ClosureChoice.keep);
  });

  test('inactivity wins over expired retention', () {
    final result = _propose(
      students: [_student('a', enrolledOn: 15, month: 9)],
      groups: [
        _group(['a']),
      ],
    );

    expect(result['a']!.reason, ClosureReason.inactive);
  });

  test('lists the students of the season, not those placed elsewhere', () {
    final result = _propose(
      students: [_student('a'), _student('b')],
      groups: [
        _group(['a']),
        _group(['b'], season: 'other').rename('Autre'),
      ],
      sessions: [
        _session(['a']),
      ],
      others: [_otherSeason()],
    );

    expect(result.keys, ['a']);
  });

  test('proposes to erase a student who never had a group', () {
    final result = _propose(
      students: [_student('a'), _student('c')],
      groups: [
        _group(['a']),
      ],
      sessions: [
        _session(['a']),
      ],
    );

    expect(result.keys, ['a', 'c']);
    expect(result['c']!.choice, ClosureChoice.erase);
    expect(result['c']!.reason, ClosureReason.inactive);
  });

  test('proposes a student whose open membership sits in a closed season', () {
    final result = _propose(
      students: [_student('a'), _student('b')],
      groups: [
        _group(['a']),
        _group(['b'], season: 'other').rename('Autre'),
      ],
      sessions: [
        _session(['a']),
      ],
      others: [_otherSeason(closed: true)],
    );

    expect(result.keys, ['a', 'b']);
    expect(result['b']!.choice, ClosureChoice.erase);
  });

  test('a student who left a group of another open season is proposed', () {
    final left = _group(
      ['b'],
      season: 'other',
    ).rename('Autre').release(studentId: const StudentId('b'), to: day(3));

    final result = _propose(
      students: [_student('b')],
      groups: [left],
      others: [_otherSeason()],
    );

    expect(result.keys, ['b']);
  });

  test('lists a student who left the group during the season', () {
    final left = _group(['a'])
        .release(studentId: const StudentId('a'), to: day(10));

    final result = _propose(
      students: [_student('a')],
      groups: [left],
      sessions: [
        _session(['a']),
      ],
    );

    expect(result.keys, ['a']);
  });

  test('lists a student once even with two memberships', () {
    final twice = _group(['a'])
        .release(studentId: const StudentId('a'), to: day(10))
        .admit(
          studentId: const StudentId('a'),
          studentAudience: Audience.children,
          from: day(11),
        );

    final result = proposeClosure(
      season: _season,
      seasons: [_season],
      students: [_student('a')],
      groups: [twice],
      sessions: [
        _session(['a']),
      ],
    );

    expect(result, hasLength(1));
  });

  test('sorts the proposals by first name', () {
    final result = proposeClosure(
      season: _season,
      seasons: [_season],
      students: [_student('zoe'), _student('ana')],
      groups: [
        _group(['zoe', 'ana']),
      ],
      sessions: [
        _session(['zoe', 'ana']),
      ],
    );

    expect(result.map((p) => p.firstName), ['ana', 'zoe']);
  });
}
