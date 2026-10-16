import 'package:billard_cfa/shared/lib/timer_tone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('timerToneFor', () {
    test('is neutral from one minute up', () {
      expect(timerToneFor(const Duration(minutes: 1)), TimerTone.neutral);
      expect(timerToneFor(const Duration(minutes: 30)), TimerTone.neutral);
    });

    test('is attention just under one minute', () {
      expect(
        timerToneFor(const Duration(seconds: 59, milliseconds: 999)),
        TimerTone.attention,
      );
      expect(timerToneFor(const Duration(seconds: 59)), TimerTone.attention);
    });

    test('is attention at zero included', () {
      expect(timerToneFor(Duration.zero), TimerTone.attention);
      expect(
        timerToneFor(const Duration(milliseconds: 1)),
        TimerTone.attention,
      );
    });

    test('is overdue strictly under zero', () {
      expect(timerToneFor(const Duration(milliseconds: -1)), TimerTone.overdue);
      expect(timerToneFor(const Duration(seconds: -1)), TimerTone.overdue);
      expect(timerToneFor(const Duration(minutes: -3)), TimerTone.overdue);
    });
  });
}
