import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/close_season/domain/build_archive.dart';
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

Group _group(
  String id,
  List<String> members, {
  Audience audience = Audience.children,
  int from = 1,
}) {
  var group = Group(
    id: GroupId(id),
    seasonId: const SeasonId('season'),
    name: id,
    audience: audience,
  );
  for (final member in members) {
    group = group.admit(
      studentId: StudentId(member),
      studentAudience: audience,
      from: day(from),
    );
  }
  return group;
}

SessionRecord _session(
  String id,
  String group,
  int dayOfMonth,
  List<String> present, {
  Audience audience = Audience.children,
  String season = 'season',
}) => SessionRecord(
  id: SessionId(id),
  groupId: GroupId(group),
  seasonId: SeasonId(season),
  date: day(dayOfMonth),
  audience: audience,
  present: {for (final name in present) StudentId(name)},
);

ExerciseAttempt _pass(
  String student,
  String session, {
  int exercise = 1,
  int potted = 3,
  int total = 5,
  int nth = 1,
  String block = 'a',
}) => attempt(
  ref(block, exercise),
  potted: potted,
  total: total,
  student: student,
  session: session,
  id: 'p-$student-$session-$block-$exercise-$nth',
);

SeasonArchive _build({
  List<Group>? groups,
  List<SessionRecord>? sessions,
  List<ExerciseAttempt> attempts = const [],
}) => buildArchive(
  season: _season,
  groups:
      groups ??
      [
        _group('g1', ['a', 'b', 'c']),
      ],
  sessions: sessions ?? const [],
  attempts: attempts,
);

void main() {
  test('an empty season gives an empty archive', () {
    final archive = _build();

    expect(archive.seasonId, const SeasonId('season'));
    expect(archive.audiences, isEmpty);
    expect(archive.exercises, isEmpty);
  });

  test('counts sessions, presences and possible presences per audience', () {
    final archive = _build(
      groups: [
        _group('g1', ['a', 'b', 'c']),
        _group('g2', ['x', 'y'], audience: Audience.adults),
      ],
      sessions: [
        _session('s1', 'g1', 3, ['a', 'b']),
        _session('s2', 'g1', 4, ['a', 'b', 'c']),
        _session('s3', 'g2', 5, ['x'], audience: Audience.adults),
      ],
    );

    final children = archive.audienceOf(Audience.children)!;
    expect(children.sessionCount, 2);
    expect(children.presenceCount, 5);
    expect(children.possiblePresenceCount, 6);
    final adults = archive.audienceOf(Audience.adults)!;
    expect(adults.sessionCount, 1);
  });

  test('under three present students, keeps the sessions and drops the '
      'presences and passes', () {
    final archive = _build(
      groups: [
        _group('g1', ['a', 'b', 'c']),
        _group('g2', ['x', 'y'], audience: Audience.adults),
      ],
      sessions: [
        _session('s1', 'g1', 3, ['a', 'b', 'c']),
        _session('s3', 'g2', 5, ['x', 'y'], audience: Audience.adults),
      ],
      attempts: [_pass('x', 's3')],
    );

    final adults = archive.audienceOf(Audience.adults)!;
    expect(adults.sessionCount, 1);
    expect(adults.studentCount, 2);
    expect(adults.presenceCount, 0);
    expect(adults.possiblePresenceCount, 0);
    expect(adults.attemptCount, 0);
    expect(archive.audienceOf(Audience.children)!.presenceCount, 3);
  });

  test('keeps the figures from exactly three present students', () {
    final archive = _build(
      sessions: [
        _session('s1', 'g1', 3, ['a', 'b', 'c']),
      ],
      attempts: [_pass('a', 's1')],
    );

    final children = archive.audienceOf(Audience.children)!;
    expect(children.presenceCount, 3);
    expect(children.attemptCount, 1);
  });

  test('possible presences use the members on the day of each session', () {
    final late = _group('g1', ['a', 'b']).admit(
      studentId: const StudentId('c'),
      studentAudience: Audience.children,
      from: day(10),
    );

    final archive = _build(
      groups: [late],
      sessions: [
        _session('s1', 'g1', 5, ['a', 'b']),
        _session('s2', 'g1', 12, ['a', 'b', 'c']),
      ],
    );

    expect(archive.audienceOf(Audience.children)!.possiblePresenceCount, 5);
  });

  test('counts distinct present students, with or without a pass', () {
    final archive = _build(
      sessions: [
        _session('s1', 'g1', 3, ['a', 'b', 'c']),
        _session('s2', 'g1', 4, ['a']),
      ],
      attempts: [_pass('a', 's1')],
    );

    expect(archive.audienceOf(Audience.children)!.studentCount, 3);
    expect(archive.audienceOf(Audience.children)!.attemptCount, 1);
  });

  test('ignores sessions and passes of another season', () {
    final archive = _build(
      sessions: [
        _session('s1', 'g1', 3, ['a', 'b', 'c']),
        _session('old', 'g1', 2, ['a', 'b'], season: 'other'),
      ],
      attempts: [_pass('a', 's1'), _pass('a', 'old'), _pass('b', 'old')],
    );

    expect(archive.audienceOf(Audience.children)!.sessionCount, 1);
    expect(archive.audienceOf(Audience.children)!.attemptCount, 1);
  });

  group('exercise lines', () {
    List<SessionRecord> sessionFor(List<String> present) => [
      _session('s1', 'g1', 3, present),
    ];

    test('are dropped under three distinct students', () {
      final archive = _build(
        sessions: sessionFor(['a', 'b', 'c']),
        attempts: [
          _pass('a', 's1'),
          _pass('a', 's1', nth: 2),
          _pass('b', 's1'),
        ],
      );

      expect(archive.exercises, isEmpty);
    });

    test('exist from exactly three distinct students', () {
      final archive = _build(
        sessions: sessionFor(['a', 'b', 'c']),
        attempts: [
          _pass('a', 's1', potted: 2),
          _pass('a', 's1', potted: 4, nth: 2),
          _pass('b', 's1', potted: 1),
          _pass('c', 's1', potted: 5),
        ],
      );

      final line = archive.exercises.single;
      expect(line.audience, Audience.children);
      expect(line.exercise, ref('a', 1));
      expect(line.studentCount, 3);
      expect(line.attemptCount, 4);
      expect(line.potted, 12);
      expect(line.total, 20);
    });

    test('count three students once even with many passes each', () {
      final archive = _build(
        sessions: sessionFor(['a', 'b', 'c', 'd']),
        attempts: [
          for (final s in ['a', 'b', 'c', 'd']) _pass(s, 's1'),
        ],
      );

      expect(archive.exercises.single.studentCount, 4);
    });

    test('are kept separately per exercise and per audience', () {
      final archive = _build(
        groups: [
          _group('g1', ['a', 'b', 'c']),
          _group('g2', ['x', 'y', 'z'], audience: Audience.adults),
        ],
        sessions: [
          _session('s1', 'g1', 3, ['a', 'b', 'c']),
          _session('s2', 'g2', 4, ['x', 'y', 'z'], audience: Audience.adults),
        ],
        attempts: [
          for (final s in ['a', 'b', 'c']) _pass(s, 's1'),
          for (final s in ['a', 'b', 'c']) _pass(s, 's1', exercise: 2),
          for (final s in ['x', 'y', 'z']) _pass(s, 's2'),
        ],
      );

      expect(archive.exercises.map((e) => (e.audience, e.exercise.number)), [
        (Audience.children, 1),
        (Audience.children, 2),
        (Audience.adults, 1),
      ]);
    });

    test('only count the passes of the season for the threshold', () {
      final archive = _build(
        sessions: [
          _session('s1', 'g1', 3, ['a', 'b']),
          _session('old', 'g1', 2, ['c'], season: 'other'),
        ],
        attempts: [_pass('a', 's1'), _pass('b', 's1'), _pass('c', 'old')],
      );

      expect(archive.exercises, isEmpty);
    });
  });

  test('carries no student identifier', () {
    final archive = _build(
      sessions: [
        _session('s1', 'g1', 3, ['a', 'b', 'c']),
      ],
      attempts: [
        for (final s in ['a', 'b', 'c']) _pass(s, 's1'),
      ],
    );

    final text = archive.toString();
    expect(text, isNot(contains('StudentId')));
    expect(text, isNot(contains('student-')));
    expect(text, isNot(contains('g1')));
    expect(text, isNot(contains('s1')));
  });
}
