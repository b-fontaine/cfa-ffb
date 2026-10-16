import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/track_group/domain/group_alerts.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

int _ids = 0;

ExerciseAttempt miss(String student, String block, int dayOfMonth) => attempt(
  ref(block, 1),
  potted: 0,
  student: student,
  dayOfMonth: dayOfMonth,
  id: 'm${_ids++}',
);

ExerciseAttempt hit(String student, String block, int dayOfMonth) => attempt(
  ref(block, 1),
  potted: 3,
  student: student,
  dayOfMonth: dayOfMonth,
  id: 'h${_ids++}',
);

SessionRecord session(int dayOfMonth) => SessionRecord(
  id: SessionId('x$dayOfMonth'),
  groupId: const GroupId('g1'),
  seasonId: const SeasonId('season'),
  date: day(dayOfMonth),
  audience: Audience.children,
  present: const {},
);

/// Séances aux jours 1 à [count] ; la fenêtre par défaut en regarde 4.
List<SessionRecord> sessions(int count) => [
  for (var d = 1; d <= count; d++) session(d),
];

List<GroupAlert> alerts(
  Map<String, List<ExerciseAttempt>> byStudent, {
  required List<String> members,
  List<SessionRecord>? groupSessions,
  RulesConfig? config,
  List<BlockAcquisition> acquisitions = const [],
  int asOf = 20,
}) {
  final rules = config ?? RulesConfig(passesRequired: 1);
  return groupFailureAlerts(
    catalogue: buildCatalogue(),
    members: [for (final name in members) StudentId(name)],
    progress: {
      for (final entry in byStudent.entries)
        StudentId(entry.key): StudentProgress.derive(
          studentId: StudentId(entry.key),
          attempts: entry.value,
          acquisitions: acquisitions,
          rates: buildCatalogue().rates,
          config: rules,
        ),
    },
    groupSessions: groupSessions ?? sessions(10),
    asOf: day(asOf),
    config: rules,
  );
}

List<String> names(int count) => [for (var i = 1; i <= count; i++) 's$i'];

void main() {
  test('raises an alert when half of the members failed the technique', () {
    final result = alerts({
      for (var i = 1; i <= 4; i++) 's$i': [miss('s$i', 'a', 9)],
    }, members: names(8));

    final alert = result.single;
    expect(alert.blockId, 'a');
    expect(alert.blockTitle, 'Bloc a');
    expect(alert.failed, 4);
    expect(alert.members, 8);
  });

  test('follows the minimal number of failing students of the config', () {
    final failing = {
      for (var i = 1; i <= 2; i++) 's$i': [miss('s$i', 'a', 9)],
    };

    expect(
      alerts(
        failing,
        members: names(2),
        config: RulesConfig(passesRequired: 1, minGroupFailures: 3),
      ),
      isEmpty,
    );
    expect(
      alerts(
        failing,
        members: names(2),
        config: RulesConfig(passesRequired: 1),
      ),
      hasLength(1),
    );
  });

  test('raises an alert for a single failing student at the border 1', () {
    final failing = {
      's1': [miss('s1', 'a', 9)],
    };

    expect(
      alerts(
        failing,
        members: ['s1'],
        config: RulesConfig(passesRequired: 1, minGroupFailures: 1),
      ),
      hasLength(1),
    );
    expect(
      alerts(failing, members: ['s1'], config: RulesConfig(passesRequired: 1)),
      isEmpty,
    );
  });

  test('raises none just under the share', () {
    final result = alerts({
      for (var i = 1; i <= 3; i++) 's$i': [miss('s$i', 'a', 9)],
    }, members: names(8));

    expect(result, isEmpty);
  });

  test('follows the share of the settings', () {
    final failing = {
      for (var i = 1; i <= 7; i++) 's$i': [miss('s$i', 'a', 9)],
      's8': [hit('s8', 'a', 9)],
    };

    expect(
      alerts(
        failing,
        members: names(8),
        config: RulesConfig(passesRequired: 1, groupFailureSharePercent: 100),
      ),
      isEmpty,
    );
    expect(
      alerts(
        {
          ...failing,
          's8': [miss('s8', 'a', 9)],
        },
        members: names(8),
        config: RulesConfig(passesRequired: 1, groupFailureSharePercent: 100),
      ),
      hasLength(1),
    );
    expect(
      alerts(
        failing,
        members: names(8),
        config: RulesConfig(passesRequired: 1, groupFailureSharePercent: 80),
      ),
      hasLength(1),
    );
  });

  test('a single failing student is an individual alert, not a group one', () {
    final result = alerts(
      {
        's1': [miss('s1', 'a', 9)],
      },
      members: ['s1'],
    );

    expect(result, isEmpty);
  });

  test('two failing students out of two raise an alert', () {
    final result = alerts(
      {
        's1': [miss('s1', 'a', 9)],
        's2': [miss('s2', 'a', 9)],
      },
      members: ['s1', 's2'],
    );

    expect(result.single.failed, 2);
    expect(result.single.members, 2);
  });

  test('members without any pass count in the denominator', () {
    final result = alerts({
      's1': [miss('s1', 'a', 9)],
      's2': [miss('s2', 'a', 9)],
    }, members: names(5));

    // 2 sur 5 = 40 % : sous les 50 %.
    expect(result, isEmpty);
  });

  test('ignores students who are not members', () {
    final result = alerts(
      {
        's1': [miss('s1', 'a', 9)],
        's2': [miss('s2', 'a', 9)],
        's3': [miss('s3', 'a', 9)],
      },
      members: ['s1', 's4'],
    );

    expect(result, isEmpty);
  });

  test('ignores a student whose last pass on the technique passed', () {
    final result = alerts(
      {
        's1': [miss('s1', 'a', 8), hit('s1', 'a', 9)],
        's2': [miss('s2', 'a', 9)],
      },
      members: ['s1', 's2'],
    );

    expect(result, isEmpty);
  });

  test('ignores failures older than the last sessions of the group', () {
    // Dix séances, fenêtre de 4 : seules celles des jours 7 à 10 comptent.
    final result = alerts({
      for (var i = 1; i <= 4; i++) 's$i': [miss('s$i', 'a', 3)],
    }, members: names(6));

    expect(result, isEmpty);
  });

  test('keeps a failure dated the day of the oldest session of the window', () {
    final inside = alerts({
      for (var i = 1; i <= 4; i++) 's$i': [miss('s$i', 'a', 7)],
    }, members: names(6));
    final outside = alerts({
      for (var i = 1; i <= 4; i++) 's$i': [miss('s$i', 'a', 6)],
    }, members: names(6));

    expect(inside, hasLength(1));
    expect(outside, isEmpty);
  });

  test('follows the window of the settings', () {
    final failing = {
      for (var i = 1; i <= 4; i++) 's$i': [miss('s$i', 'a', 3)],
    };

    final result = alerts(
      failing,
      members: names(6),
      config: RulesConfig(passesRequired: 1, recallStaleSessions: 8),
    );

    expect(result, hasLength(1));
  });

  test('with fewer sessions than the window every failure counts', () {
    final result = alerts(
      {
        for (var i = 1; i <= 4; i++) 's$i': [miss('s$i', 'a', 1)],
      },
      members: names(6),
      groupSessions: sessions(2),
    );

    expect(result, hasLength(1));
  });

  test('ignores the sessions after the as-of day when placing the window', () {
    // Séances 1 à 10 mais "aujourd'hui" = jour 5 : fenêtre = jours 2 à 5.
    final result = alerts(
      {
        for (var i = 1; i <= 4; i++) 's$i': [miss('s$i', 'a', 3)],
      },
      members: names(6),
      asOf: 5,
    );

    expect(result, hasLength(1));
  });

  test('does not count an exercise acquired at placement', () {
    final result = alerts(
      {
        for (var i = 1; i <= 4; i++) 's$i': [miss('s$i', 'a', 2)],
      },
      members: names(6),
      // s1 et s2 ont l'exercice acquis (leurs échecs sont dormants) : il reste
      // 2 élèves sur 6 en échec, sous les 50 %.
      acquisitions: [
        for (final student in ['s1', 's2'])
          acquisition('a', day: 5, student: student, id: 'q$student'),
      ],
    );

    expect(result, isEmpty);
  });

  test('orders the alerts by share, then by teaching order', () {
    final result = alerts({
      's1': [miss('s1', 'c', 9), miss('s1', 'b', 9), miss('s1', 'a', 9)],
      's2': [miss('s2', 'c', 9), miss('s2', 'b', 9), miss('s2', 'a', 9)],
      's3': [miss('s3', 'c', 9), miss('s3', 'b', 9)],
      's4': [miss('s4', 'c', 9)],
    }, members: names(4));

    // c : 4/4, b : 3/4, a : 2/4.
    expect(result.map((a) => a.blockId), ['c', 'b', 'a']);
  });

  test('breaks a tie on the share by teaching order', () {
    final result = alerts(
      {
        's1': [miss('s1', 'b', 9), miss('s1', 'a', 9)],
        's2': [miss('s2', 'b', 9), miss('s2', 'a', 9)],
      },
      members: ['s1', 's2'],
    );

    expect(result.map((a) => a.blockId), ['a', 'b']);
  });

  test('uses the most recent pass of the technique across its exercises', () {
    final result = alerts(
      {
        // Réussite sur a2 après l'échec sur a1 : le dernier passage a réussi.
        's1': [
          miss('s1', 'a', 8),
          attempt(ref('a', 2), potted: 3, dayOfMonth: 9, id: 'late'),
        ],
        's2': [miss('s2', 'a', 9)],
      },
      members: ['s1', 's2'],
    );

    expect(result, isEmpty);
  });

  test('computes the share and the failed count', () {
    final alert = alerts({
      for (var i = 1; i <= 5; i++) 's$i': [miss('s$i', 'a', 9)],
    }, members: names(8)).single;

    expect(alert.sharePercent, 62);
  });

  test('applies no window for a group without any recorded session', () {
    final result = alerts(
      {
        for (var i = 1; i <= 4; i++) 's$i': [miss('s$i', 'a', 1)],
      },
      members: names(6),
      groupSessions: const [],
    );

    expect(result.single.failed, 4);
    expect(result.single.members, 6);
  });

  test('applies no window when every session is after the reference day', () {
    final result = alerts(
      {
        for (var i = 1; i <= 4; i++) 's$i': [miss('s$i', 'a', 1)],
      },
      members: names(6),
      groupSessions: sessions(10),
      asOf: 0,
    );

    expect(result.single.failed, 4);
  });

  test('two members out of three reach a 66 % share but not a 67 % one', () {
    final byStudent = {
      for (var i = 1; i <= 2; i++) 's$i': [miss('s$i', 'a', 9)],
    };

    expect(
      alerts(
        byStudent,
        members: names(3),
        config: RulesConfig(passesRequired: 1, groupFailureSharePercent: 66),
      ),
      hasLength(1),
    );
    expect(
      alerts(
        byStudent,
        members: names(3),
        config: RulesConfig(passesRequired: 1, groupFailureSharePercent: 67),
      ),
      isEmpty,
    );
  });
}
