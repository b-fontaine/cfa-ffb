import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/track_progress/domain/week_summary.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

void main() {
  final today = day(12);
  final a1 = ref('a', 1);
  final config = RulesConfig(passesRequired: 2);
  var ids = 0;

  ExerciseAttempt pass(int dayOfMonth, {bool passed = true}) => attempt(
    a1,
    potted: passed ? 3 : 1,
    dayOfMonth: dayOfMonth,
    id: 'p${ids++}',
  );

  SessionRecord record(int dayOfMonth) => SessionRecord(
    id: SessionId('x$dayOfMonth'),
    groupId: const GroupId('g1'),
    seasonId: const SeasonId('season'),
    date: day(dayOfMonth),
    audience: Audience.children,
    present: const {},
  );

  WeekSummary summarize(
    List<ExerciseAttempt> attempts,
    List<SessionRecord> records, {
    DateTime? on,
  }) => weekSummary(
    today: on ?? today,
    attempts: attempts,
    progress: [
      StudentProgress.derive(
        studentId: const StudentId('s1'),
        attempts: attempts,
        acquisitions: const [],
        rates: buildCatalogue().rates,
        config: config,
      ),
    ],
    records: records,
  );

  test('is a window of seven days ending today', () {
    final summary = summarize(const [], const []);

    expect(summary.from, day(6));
    expect(summary.to, today);
  });

  test('counts a pass of day J-6 and not one of day J-7', () {
    final summary = summarize([pass(6), pass(5)], const []);

    expect(summary.passes, 1);
  });

  test('counts a pass of today and not one of tomorrow', () {
    final summary = summarize([pass(12), pass(13)], const []);

    expect(summary.passes, 1);
  });

  test('counts failed passes too', () {
    final summary = summarize([pass(10, passed: false), pass(10)], const []);

    expect(summary.passes, 2);
  });

  test('counts a validation obtained in the window', () {
    final summary = summarize([pass(3), pass(9)], const []);

    expect(summary.validations, 1);
  });

  test('does not count a validation obtained before the window', () {
    final summary = summarize([pass(2), pass(3), pass(9)], const []);

    expect(summary.validations, 0);
  });

  test('counts the sessions given in the window', () {
    final summary = summarize(const [], [record(5), record(6), record(12)]);

    expect(summary.sessions, 2);
  });

  test('ignores the time of the day of today', () {
    final summary = summarize(
      [pass(6)],
      const [],
      on: DateTime(2026, 10, 12, 23),
    );

    expect(summary.passes, 1);
  });
}
