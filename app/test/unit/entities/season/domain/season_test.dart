import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

Season season(int from, int to, {String label = '2026-2027'}) => Season(
  id: const SeasonId('s'),
  label: label,
  startDate: day(from),
  endDate: day(to),
);

void main() {
  test('refuses a blank label', () {
    expect(() => season(1, 10, label: ' '), violation(InvariantCode.blankName));
  });

  test('refuses an end date equal to the start date', () {
    expect(() => season(5, 5), violation(InvariantCode.invalidPeriod));
  });

  test('refuses an end date before the start date', () {
    expect(() => season(6, 5), violation(InvariantCode.invalidPeriod));
  });

  test('accepts an end date one day after', () {
    expect(season(5, 6).label, '2026-2027');
  });

  group('contains', () {
    final s = season(10, 20);

    test('is true on both bounds', () {
      expect(s.contains(day(10)), isTrue);
      expect(s.contains(day(20)), isTrue);
    });

    test('is false the day before and the day after', () {
      expect(s.contains(day(9)), isFalse);
      expect(s.contains(day(21)), isFalse);
    });
  });

  group('overlaps', () {
    final s = season(10, 20);

    test('is true when sharing the boundary day', () {
      expect(s.overlaps(season(20, 25)), isTrue);
      expect(s.overlaps(season(5, 10)), isTrue);
    });

    test('is true when nested', () {
      expect(s.overlaps(season(12, 15)), isTrue);
      expect(season(12, 15).overlaps(s), isTrue);
    });

    test('is false when strictly before or after', () {
      expect(s.overlaps(season(21, 25)), isFalse);
      expect(s.overlaps(season(1, 9)), isFalse);
    });
  });
}
