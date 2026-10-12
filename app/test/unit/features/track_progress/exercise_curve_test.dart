import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/features/track_progress/domain/exercise_curve.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

final ExerciseRef _exercise = ref('a', 1);

/// Courbe d'un élève sur un exercice 5/10 ; [pottedList] = billes empochées
/// de chaque passage sur 10, un passage par jour (sessions `x<jour>`).
ExerciseCurve curve(
  List<int> pottedList, {
  RulesConfig? config,
  List<int>? days,
}) {
  final cfg = config ?? RulesConfig();
  final result = ExerciseResult.derive(
    studentId: const StudentId('s1'),
    exercise: _exercise,
    rate: rate(5, 10),
    attempts: [
      for (var i = 0; i < pottedList.length; i++)
        attempt(
          _exercise,
          potted: pottedList[i],
          total: 10,
          dayOfMonth: days?[i] ?? i + 1,
          session: 'x${days?[i] ?? i + 1}',
          id: 'a$i',
        ),
    ],
    config: cfg,
  );
  return ExerciseCurve.of(result, cfg);
}

void main() {
  group('empty curve', () {
    final empty = curve([]);

    test('has no point and no metric', () {
      expect(empty.points, isEmpty);
      expect(empty.best, isNull);
      expect(empty.delta, isNull);
      expect(empty.slope, isNull);
      expect(empty.relativeScore, isNull);
      expect(empty.movingAverage, isEmpty);
      expect(empty.passesToValidation, isNull);
      expect(empty.sessionsToValidation, isNull);
      expect(empty.stagnating, isFalse);
    });
  });

  group('the memento example 5/10, 7/10, 6/10, 8/10', () {
    final c = curve([5, 7, 6, 8]);

    test('lists the points in order, indexed from 1', () {
      expect(c.points.map((p) => p.potted), [5, 7, 6, 8]);
      expect(c.points.map((p) => p.index), [1, 2, 3, 4]);
      expect(c.points.map((p) => p.date), [day(1), day(2), day(3), day(4)]);
      expect(c.points.first.sessionId, const SessionId('x1'));
      expect(c.points.first.total, 10);
      expect(c.points.map((p) => p.passed), [true, true, true, true]);
    });

    test('best result is 8 on 10', () {
      expect(c.best!.potted, 8);
      expect(c.best!.total, 10);
      expect(c.best!.ratio, closeTo(0.8, 1e-9));
    });

    test('delta is last minus first ratio', () {
      expect(c.delta, closeTo(0.3, 1e-9));
    });

    test('slope is positive (regression of the ratios)', () {
      expect(c.slope, closeTo(0.08, 1e-9));
    });

    test('moving average over 3 passes', () {
      expect(c.movingAverage, hasLength(2));
      expect(c.movingAverage[0], closeTo(0.6, 1e-9));
      expect(c.movingAverage[1], closeTo(0.7, 1e-9));
    });

    test('relative score compares the last pass to the required rate', () {
      expect(c.relativeScore, closeTo(1.6, 1e-9));
    });

    test('is not validated yet', () {
      expect(c.passesToValidation, isNull);
      expect(c.stagnating, isFalse);
    });
  });

  group('best result', () {
    test('keeps the earliest of two equal best passes', () {
      final c = curve([8, 5, 8]);

      expect(c.best!.index, 1);
    });
  });

  group('slope window', () {
    test('uses a single pass as no slope', () {
      expect(curve([7]).slope, isNull);
    });

    test('is exactly the step for two passes', () {
      expect(curve([5, 7]).slope, closeTo(0.2, 1e-9));
    });

    test('only considers the last trendWindow passes', () {
      // 3 passes ignorés (0,0,0) puis 5,6,7,8,9 : pente 0.1
      final c = curve([0, 0, 0, 5, 6, 7, 8, 9]);

      expect(c.slope, closeTo(0.1, 1e-9));
    });

    test('is negative when the results decline', () {
      expect(curve([9, 7, 5]).slope, closeTo(-0.2, 1e-9));
    });

    test('follows the configured window of 2', () {
      final c = curve([9, 1, 2], config: RulesConfig(trendWindow: 2));

      expect(c.slope, closeTo(0.1, 1e-9));
    });
  });

  group('moving average', () {
    test('is empty with fewer passes than the window', () {
      expect(curve([5, 6]).movingAverage, isEmpty);
    });

    test('has one value for exactly the window size', () {
      final c = curve([5, 6, 7]);

      expect(c.movingAverage, hasLength(1));
      expect(c.movingAverage.single, closeTo(0.6, 1e-9));
    });

    test('follows the configured window of 2', () {
      final c = curve([5, 7, 9], config: RulesConfig(movingAverageWindow: 2));

      expect(c.movingAverage[0], closeTo(0.6, 1e-9));
      expect(c.movingAverage[1], closeTo(0.8, 1e-9));
    });
  });

  group('validation', () {
    test('counts passes and sessions up to the fifth passed pass', () {
      final c = curve([5, 4, 5, 6, 5, 8, 9]);

      expect(c.passesToValidation, 6);
      expect(c.sessionsToValidation, 6);
    });

    test('counts distinct sessions, not passes', () {
      final c = curve([5, 5, 5, 5, 5], days: [1, 1, 2, 2, 3]);

      expect(c.passesToValidation, 5);
      expect(c.sessionsToValidation, 3);
    });

    test('4 passed passes are not enough, 5 are', () {
      expect(curve([5, 5, 5, 5]).passesToValidation, isNull);
      expect(curve([5, 5, 5, 5, 5]).passesToValidation, 5);
    });

    test('is not moved by passes after the validation', () {
      expect(curve([5, 5, 5, 5, 5, 5, 5]).passesToValidation, 5);
    });

    test('follows the configured number of passes', () {
      final c = curve([4, 5], config: RulesConfig(passesRequired: 1));

      expect(c.passesToValidation, 2);
      expect(c.sessionsToValidation, 2);
    });
  });

  group('stagnation', () {
    test('5 passes without validation and a flat slope stagnate', () {
      expect(curve([4, 4, 4, 4, 4]).stagnating, isTrue);
    });

    test('a declining slope stagnates too', () {
      expect(curve([4, 4, 3, 3, 2]).stagnating, isTrue);
    });

    test('a rising slope does not stagnate', () {
      expect(curve([1, 2, 3, 4, 4]).stagnating, isFalse);
    });

    test('4 passes are not enough', () {
      expect(curve([4, 4, 4, 4]).stagnating, isFalse);
    });

    test('a validated exercise does not stagnate', () {
      expect(curve([5, 5, 5, 5, 5]).stagnating, isFalse);
    });

    test('follows the configured number of passes', () {
      final c = curve([4, 4], config: RulesConfig(stagnationPasses: 2));

      expect(c.stagnating, isTrue);
    });
  });
}
