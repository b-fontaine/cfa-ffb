import 'package:billard_cfa/features/review_session/domain/next_session_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Aujourd'hui : lundi 12 octobre 2026.
  final today = DateTime(2026, 10, 12);

  test('is the same weekday, the following week', () {
    final next = nextSameWeekday(given: DateTime(2026, 10, 12), today: today);

    expect(next, DateTime(2026, 10, 19));
    expect(next.weekday, DateTime.monday);
  });

  test('a session given last week proposes the weekday after today', () {
    final next = nextSameWeekday(given: DateTime(2026, 10, 8), today: today);

    expect(next, DateTime(2026, 10, 15));
  });

  test('a date in the past is moved by whole weeks after today', () {
    final next = nextSameWeekday(given: DateTime(2026, 9, 14), today: today);

    expect(next, DateTime(2026, 10, 19));
  });

  test('is strictly after today, never today itself', () {
    final next = nextSameWeekday(given: DateTime(2026, 10, 5), today: today);

    expect(next, DateTime(2026, 10, 19));
  });

  test('keeps midnight across the end of daylight saving time', () {
    final next = nextSameWeekday(
      given: DateTime(2026, 10, 19),
      today: DateTime(2026, 10, 19),
    );

    expect(next, DateTime(2026, 10, 26));
    expect(next.hour, 0);
  });

  test('ignores the time of the day of the given date and today', () {
    final next = nextSameWeekday(
      given: DateTime(2026, 10, 12, 18, 30),
      today: DateTime(2026, 10, 12, 23),
    );

    expect(next, DateTime(2026, 10, 19));
  });

  test('a session given in the future proposes the week after it', () {
    final next = nextSameWeekday(given: DateTime(2026, 10, 20), today: today);

    expect(next, DateTime(2026, 10, 27));
  });

  group('plannableDates', () {
    final range = plannableDates(today);

    test('refuses today and accepts tomorrow', () {
      expect(range.contains(DateTime(2026, 10, 12)), isFalse);
      expect(range.contains(DateTime(2026, 10, 13)), isTrue);
      expect(range.first, DateTime(2026, 10, 13));
    });

    test('accepts exactly one year from today and refuses the next day', () {
      expect(range.last, DateTime(2027, 10, 12));
      expect(range.contains(DateTime(2027, 10, 12)), isTrue);
      expect(range.contains(DateTime(2027, 10, 13)), isFalse);
    });

    test('ignores the time of day', () {
      expect(range.contains(DateTime(2027, 10, 12, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 10, 12, 23, 59)), isFalse);
    });

    test('does not depend on the date already chosen', () {
      expect(plannableDates(today).last, range.last);
    });

    test('a 29 February today ends on the last day of February', () {
      expect(plannableDates(DateTime(2028, 2, 29)).last, DateTime(2029, 2, 28));
    });

    test('clamps a date into the range', () {
      expect(range.clamp(DateTime(2026, 10)), DateTime(2026, 10, 13));
      expect(range.clamp(DateTime(2026, 11, 2)), DateTime(2026, 11, 2));
      expect(range.clamp(DateTime(2030)), DateTime(2027, 10, 12));
    });
  });
}
