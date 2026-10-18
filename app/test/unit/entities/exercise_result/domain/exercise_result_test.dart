import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

final ExerciseRef _exercise = ref('a', 1);

/// Passages successifs sur 3/5 : `true` = réussi (3 sur 5), `false` = 2 sur 5.
/// Un passage par jour, à partir du 1er.
ExerciseResult derive(List<bool> passes, {RulesConfig? config}) =>
    ExerciseResult.derive(
      studentId: const StudentId('s1'),
      exercise: _exercise,
      rate: rate(),
      attempts: [
        for (var i = 0; i < passes.length; i++)
          attempt(
            _exercise,
            potted: passes[i] ? 3 : 2,
            dayOfMonth: i + 1,
            id: 'a$i',
          ),
      ],
      config: config ?? RulesConfig(),
    );

void main() {
  group('status', () {
    test('is notStarted without any pass', () {
      final result = derive([]);

      expect(result.status, ExerciseStatus.notStarted);
      expect(result.passedCount, 0);
      expect(result.lastAttempt, isNull);
      expect(result.lastFailed, isFalse);
      expect(result.lastRelativeScore, isNull);
    });

    test('is inProgress after a failed pass', () {
      expect(derive([false]).status, ExerciseStatus.inProgress);
    });

    test('is inProgress with 4 passed passes', () {
      final result = derive([true, true, true, true]);

      expect(result.status, ExerciseStatus.inProgress);
      expect(result.passedCount, 4);
      expect(result.isValidated, isFalse);
      expect(result.validatedOn, isNull);
    });

    test('is validated with exactly 5 passed passes', () {
      final result = derive([true, true, true, true, true]);

      expect(result.status, ExerciseStatus.validated);
      expect(result.isValidated, isTrue);
      expect(result.validatedOn, day(5));
    });

    test('stays validated with 6 passed passes and keeps the first date', () {
      final result = derive([true, true, true, true, true, true]);

      expect(result.isValidated, isTrue);
      expect(result.passedCount, 6);
      expect(result.validatedOn, day(5));
    });

    test('counts passed passes that are not consecutive', () {
      final result = derive([true, false, true, false, true, true, true]);

      expect(result.passedCount, 5);
      expect(result.isValidated, isTrue);
      expect(result.validatedOn, day(7));
    });

    test('validation is monotone: later failures do not remove it', () {
      final result = derive([true, true, true, true, true, false, false]);

      expect(result.isValidated, isTrue);
      expect(result.consecutiveFailures, 2);
    });

    test('follows a configured number of passes (1 and 2)', () {
      expect(
        derive([true], config: RulesConfig(passesRequired: 1)).isValidated,
        isTrue,
      );
      expect(
        derive([true], config: RulesConfig(passesRequired: 2)).isValidated,
        isFalse,
      );
      expect(
        derive([
          true,
          true,
        ], config: RulesConfig(passesRequired: 2)).isValidated,
        isTrue,
      );
    });
  });

  group('R4 consecutive failures alert', () {
    test('2 consecutive failures: no alert', () {
      final result = derive([false, false]);

      expect(result.consecutiveFailures, 2);
      expect(result.alert, AlertLevel.none);
      expect(result.hasActiveAlert, isFalse);
    });

    test('3 consecutive failures: attention', () {
      final result = derive([false, false, false]);

      expect(result.alert, AlertLevel.attention);
      expect(result.hasActiveAlert, isTrue);
    });

    test('4 consecutive failures: still attention', () {
      expect(derive([false, false, false, false]).alert, AlertLevel.attention);
    });

    test('5 consecutive failures: persistent', () {
      expect(derive(List.filled(5, false)).alert, AlertLevel.persistent);
    });

    test('6 consecutive failures: persistent', () {
      expect(derive(List.filled(6, false)).alert, AlertLevel.persistent);
    });

    test('a pass resolves the alert', () {
      final result = derive([false, false, false, true]);

      expect(result.consecutiveFailures, 0);
      expect(result.alert, AlertLevel.none);
    });

    test('only failures after the last pass count', () {
      final result = derive([false, false, true, false, false]);

      expect(result.consecutiveFailures, 2);
      expect(result.alert, AlertLevel.none);
    });

    test('uses the configured threshold', () {
      final config = RulesConfig(
        alertThreshold: 2,
        persistentAlertThreshold: 4,
      );

      expect(
        derive([false, false], config: config).alert,
        AlertLevel.attention,
      );
      expect(
        derive([false, false, false, false], config: config).alert,
        AlertLevel.persistent,
      );
    });

    test('a validated exercise raises no alert', () {
      final passes = [true, true, true, true, true, false, false, false];

      expect(derive(passes).alert, AlertLevel.none);
    });
  });

  group('ordering and last pass', () {
    test('sorts passes by date, keeping the recorded order on a tie', () {
      final result = ExerciseResult.derive(
        studentId: const StudentId('s1'),
        exercise: _exercise,
        rate: rate(),
        attempts: [
          attempt(_exercise, potted: 2, dayOfMonth: 2, id: 'z'),
          attempt(_exercise, potted: 3, dayOfMonth: 2, id: 'a'),
          attempt(_exercise, potted: 4, id: 'b'),
        ],
        config: RulesConfig(),
      );

      // Le rang est dérivé : à égalité de date, l'ordre d'enregistrement du
      // dépôt (jamais l'identifiant) tranche ; le tri est stable.
      expect(result.attempts.map((a) => a.id.value), ['b', 'z', 'a']);
      expect(result.lastAttempt!.id.value, 'a');
    });

    test('the rank of the last pass counts the passes of its session', () {
      final result = ExerciseResult.derive(
        studentId: const StudentId('s1'),
        exercise: _exercise,
        rate: rate(),
        attempts: [
          attempt(_exercise, potted: 2, id: 'p1'),
          attempt(_exercise, potted: 3, id: 'p2'),
          attempt(_exercise, potted: 4, id: 'p3', session: 'x2', dayOfMonth: 2),
        ],
        config: RulesConfig(),
      );

      expect(result.lastAttemptRank, 1);
      expect(
        ExerciseResult.derive(
          studentId: const StudentId('s1'),
          exercise: _exercise,
          rate: rate(),
          attempts: [
            attempt(_exercise, potted: 2, id: 'p1'),
            attempt(_exercise, potted: 3, id: 'p2'),
          ],
          config: RulesConfig(),
        ).lastAttemptRank,
        2,
      );
    });

    test('lastFailed is true when the last pass missed the rate', () {
      expect(derive([true, false]).lastFailed, isTrue);
      expect(derive([false, true]).lastFailed, isFalse);
    });

    test('relative score compares the last pass to the required rate', () {
      expect(derive([true]).lastRelativeScore, closeTo(1, 1e-9));
      expect(derive([false]).lastRelativeScore, closeTo(2 / 3, 1e-9));
    });
  });
}
