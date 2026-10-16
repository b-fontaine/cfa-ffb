import 'package:billard_cfa/features/run_sheet/domain/run_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runTimerRemaining', () {
    test('is the whole budget before the first second', () {
      expect(
        runTimerRemaining(plannedMinutes: 35, elapsedSeconds: 0),
        const Duration(minutes: 35),
      );
    });

    test('counts down second by second', () {
      expect(
        runTimerRemaining(plannedMinutes: 10, elapsedSeconds: 61),
        const Duration(minutes: 8, seconds: 59),
      );
    });

    test('is zero at the exact end of the budget', () {
      expect(
        runTimerRemaining(plannedMinutes: 10, elapsedSeconds: 600),
        Duration.zero,
      );
    });

    test('goes negative once the budget is exceeded', () {
      expect(
        runTimerRemaining(plannedMinutes: 10, elapsedSeconds: 601),
        const Duration(seconds: -1),
      );
    });
  });
}
