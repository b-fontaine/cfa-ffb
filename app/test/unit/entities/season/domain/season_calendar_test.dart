import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_calendar.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

Season _season(DateTime start, DateTime end, {DateTime? closedOn}) => Season(
  id: const SeasonId('prev'),
  label: '2026-2027',
  startDate: start,
  endDate: end,
  closedOn: closedOn,
);

void main() {
  const id = SeasonId('new');

  group('schoolYearSeason', () {
    test('covers September to August around a winter day', () {
      final season = schoolYearSeason(DateTime(2027, 2, 3), id);

      expect(season.label, '2026-2027');
      expect(season.startDate, DateTime(2026, 9));
      expect(season.endDate, DateTime(2027, 8, 31));
      expect(season.id, id);
    });

    test('starts in September for a day of the autumn', () {
      expect(schoolYearSeason(DateTime(2026, 10, 12), id).label, '2026-2027');
    });

    test('prepares the next year from July', () {
      final season = schoolYearSeason(DateTime(2027, 7), id);

      expect(season.label, '2027-2028');
      expect(season.startDate, DateTime(2027, 9));
    });

    test('keeps June in the year that ends', () {
      expect(schoolYearSeason(DateTime(2027, 6, 30), id).label, '2026-2027');
    });
  });

  group('nextSeasonAfter', () {
    test('starts in September after a season that ended in June', () {
      final next = nextSeasonAfter(
        _season(DateTime(2026, 9), DateTime(2027, 6, 30)),
        id,
      );

      expect(next.label, '2027-2028');
      expect(next.startDate, DateTime(2027, 9));
      expect(next.endDate, DateTime(2028, 8, 31));
    });

    test('starts in September after a season that ended on 31 August', () {
      final next = nextSeasonAfter(
        _season(DateTime(2026, 9), DateTime(2027, 8, 31)),
        id,
      );

      expect(next.startDate, DateTime(2027, 9));
      expect(next.label, '2027-2028');
    });

    test('starts the day after an early closure', () {
      final next = nextSeasonAfter(
        _season(
          DateTime(2026, 9),
          DateTime(2026, 10, 12),
          closedOn: DateTime(2026, 10, 12),
        ),
        id,
      );

      expect(next.startDate, DateTime(2026, 10, 13));
      expect(next.endDate, DateTime(2027, 8, 31));
    });

    test('goes past a label already taken by another season', () {
      final next = nextSeasonAfter(
        _season(
          DateTime(2026, 9),
          DateTime(2026, 10, 12),
          closedOn: DateTime(2026, 10, 12),
        ),
        id,
        takenLabels: {'2026-2027 (2)'},
      );

      expect(next.label, '2026-2027 (3)');
    });

    test('does not reuse the label of the closed season', () {
      final next = nextSeasonAfter(
        _season(
          DateTime(2026, 9),
          DateTime(2026, 10, 12),
          closedOn: DateTime(2026, 10, 12),
        ),
        id,
      );

      expect(next.label, isNot('2026-2027'));
      expect(next.label, '2026-2027 (2)');
    });
  });
}
