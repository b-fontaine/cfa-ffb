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

  group('closure', () {
    Season closed(int from, int to, int on) => Season(
      id: const SeasonId('s'),
      label: '2026-2027',
      startDate: day(from),
      endDate: day(to),
      closedOn: day(on),
    );

    test('a season is open by default', () {
      expect(season(10, 20).closedOn, isNull);
      expect(season(10, 20).isClosed, isFalse);
    });

    test('is open on a day of its period', () {
      expect(season(10, 20).isOpenOn(day(15)), isTrue);
      expect(season(10, 20).isOpenOn(day(21)), isFalse);
    });

    test('is open on its first and last day, not the day around them', () {
      final s = season(10, 20);

      expect(s.isOpenOn(day(10)), isTrue);
      expect(s.isOpenOn(day(20)), isTrue);
      expect(s.isOpenOn(day(9)), isFalse);
      expect(s.isOpenOn(day(21)), isFalse);
    });

    test('a closed season is open on no day, even inside its period', () {
      final s = closed(10, 20, 15);

      expect(s.isClosed, isTrue);
      expect(s.isOpenOn(day(12)), isFalse);
      expect(s.contains(day(12)), isTrue);
    });

    // L'entité accepte une clôture le jour de début (données importées) ;
    // `CloseSeason` est plus stricte : elle exige un jour postérieur au début.
    test('accepts a closure on the start day or after the end', () {
      expect(closed(10, 20, 10).isClosed, isTrue);
      expect(closed(10, 20, 11).isClosed, isTrue);
      expect(closed(10, 20, 25).isClosed, isTrue);
    });

    test('refuses a closure before the start', () {
      expect(() => closed(10, 20, 9), violation(InvariantCode.invalidPeriod));
    });
  });
}
