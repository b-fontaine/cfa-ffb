import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

void main() {
  group('construction', () {
    test('accepts 1 on 1', () {
      expect(SuccessRate(successes: 1, attempts: 1).attempts, 1);
    });

    test('accepts the maximum axis value 16 on 16', () {
      expect(SuccessRate(successes: 16, attempts: 16).successes, 16);
    });

    test('refuses 0 required successes', () {
      expect(
        () => SuccessRate(successes: 0, attempts: 5),
        violation(InvariantCode.successRateOutOfRange),
      );
    });

    test('refuses more successes than attempts', () {
      expect(
        () => SuccessRate(successes: 6, attempts: 5),
        violation(InvariantCode.successRateOutOfRange),
      );
    });

    test('accepts as many successes as attempts', () {
      expect(SuccessRate(successes: 5, attempts: 5).successes, 5);
    });

    test('refuses 17 attempts (axis goes to 16)', () {
      expect(
        () => SuccessRate(successes: 3, attempts: 17),
        violation(InvariantCode.successRateOutOfRange),
      );
    });
  });

  group('isReachedBy', () {
    final seven = SuccessRate(successes: 7, attempts: 9);

    test('is reached exactly at the required count', () {
      expect(seven.isReachedBy(potted: 7, total: 9), isTrue);
    });

    test('is missed one below the required count', () {
      expect(seven.isReachedBy(potted: 6, total: 9), isFalse);
    });

    test('is reached above the required count', () {
      expect(seven.isReachedBy(potted: 8, total: 9), isTrue);
    });

    test('compares proportions when the total is larger (equal ratio)', () {
      final half = SuccessRate(successes: 5, attempts: 10);

      expect(half.isReachedBy(potted: 6, total: 12), isTrue);
    });

    test('compares proportions when the total is larger (below ratio)', () {
      final half = SuccessRate(successes: 5, attempts: 10);

      expect(half.isReachedBy(potted: 5, total: 12), isFalse);
    });

    test('compares proportions when the total is larger (above ratio)', () {
      final half = SuccessRate(successes: 5, attempts: 10);

      expect(half.isReachedBy(potted: 7, total: 12), isTrue);
    });

    test('is never reached with fewer attempts than the sheet requires', () {
      expect(seven.isReachedBy(potted: 1, total: 1), isFalse);
      expect(seven.isReachedBy(potted: 8, total: 8), isFalse);
      expect(seven.isReachedBy(potted: 7, total: 8), isFalse);
    });

    test('accepts the total of the sheet as the minimum', () {
      expect(seven.isReachedBy(potted: 9, total: 9), isTrue);
    });
  });

  group('acceptsTotal', () {
    final seven = SuccessRate(successes: 7, attempts: 9);

    test('refuses a total below the attempts of the sheet', () {
      expect(seven.acceptsTotal(8), isFalse);
    });

    test('accepts the attempts of the sheet and above', () {
      expect(seven.acceptsTotal(9), isTrue);
      expect(seven.acceptsTotal(16), isTrue);
    });
  });

  group('relativeScore', () {
    test('is 1 when the rate is exactly reached', () {
      final rate = SuccessRate(successes: 7, attempts: 9);

      expect(rate.relativeScore(potted: 7, total: 9), 1);
    });

    test('is below 1 when the rate is missed', () {
      final rate = SuccessRate(successes: 6, attempts: 8);

      expect(rate.relativeScore(potted: 3, total: 8), closeTo(0.5, 1e-9));
    });

    test('is above 1 when the rate is exceeded', () {
      final rate = SuccessRate(successes: 4, attempts: 8);

      expect(rate.relativeScore(potted: 8, total: 8), closeTo(2, 1e-9));
    });
  });
}
