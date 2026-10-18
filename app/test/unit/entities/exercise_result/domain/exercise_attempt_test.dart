import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

ExerciseAttempt build({int potted = 3, int total = 5}) => ExerciseAttempt(
  id: const AttemptId('a'),
  studentId: const StudentId('s'),
  sessionId: const SessionId('x'),
  exercise: ref('a', 1),
  date: day(1),
  potted: potted,
  total: total,
);

void main() {
  group('invariants', () {
    test('accepts 0 on 1', () {
      expect(build(potted: 0, total: 1).potted, 0);
    });

    test('accepts potted equal to total', () {
      expect(build(potted: 9, total: 9).ratio, 1);
    });

    test('accepts the maximum total of 16', () {
      expect(build(potted: 16, total: 16).total, 16);
    });

    test('refuses a total of 17', () {
      expect(() => build(total: 17), violation(InvariantCode.totalOutOfRange));
    });

    test('refuses a total of 0', () {
      expect(
        () => build(potted: 0, total: 0),
        violation(InvariantCode.totalOutOfRange),
      );
    });

    test('refuses a negative potted count', () {
      expect(() => build(potted: -1), violation(InvariantCode.negativePotted));
    });

    test('refuses more potted than total', () {
      expect(
        () => build(potted: 10, total: 9),
        violation(InvariantCode.pottedExceedsTotal),
      );
    });

    test('refuses one more than total', () {
      expect(
        () => build(potted: 6),
        violation(InvariantCode.pottedExceedsTotal),
      );
    });
  });

  group('R1 passage validation', () {
    final required = rate(7, 9);

    test('7 on 9 passes', () {
      expect(build(potted: 7, total: 9).isPassed(required), isTrue);
    });

    test('6 on 9 does not pass', () {
      expect(build(potted: 6, total: 9).isPassed(required), isFalse);
    });

    test('8 on 9 passes', () {
      expect(build(potted: 8, total: 9).isPassed(required), isTrue);
    });

    test('is evaluated by proportion when the total differs', () {
      expect(build(potted: 14, total: 18 - 2).isPassed(required), isTrue);
      expect(build(potted: 5, total: 7).isPassed(required), isFalse);
    });

    test('a total below the sheet never passes, whatever the proportion', () {
      expect(build(potted: 1, total: 1).isPassed(required), isFalse);
      expect(build(potted: 8, total: 8).isPassed(required), isFalse);
    });

    test('flags a total different from the catalogue', () {
      expect(build(total: 9).hasCustomTotal(required), isFalse);
      expect(build(total: 8).hasCustomTotal(required), isTrue);
    });

    test('exposes the ratio', () {
      expect(build(potted: 7, total: 9).ratio, closeTo(7 / 9, 1e-9));
    });
  });
}
