import 'package:billard_cfa/entities/session_record/domain/record_matching.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

SessionRecord record(
  String id,
  int dayOfMonth, {
  String? sheet,
  DateTime? at,
}) => SessionRecord(
  id: SessionId(id),
  groupId: const GroupId('g1'),
  seasonId: const SeasonId('season'),
  date: at ?? DateTime(2026, 10, dayOfMonth, 17),
  audience: Audience.children,
  present: const {},
  sheetId: sheet == null ? null : SheetId(sheet),
);

void main() {
  final posture = SheetId('posture-1');
  final demi = SheetId('demi-bille-2');
  final noon = DateTime(2026, 10, 12, 8);

  group('sameSitting', () {
    test('two identical catalogue sessions are the same sitting', () {
      expect(sameSitting(posture, SheetId('posture-1')), isTrue);
    });

    test('two different catalogue sessions are never the same sitting', () {
      expect(sameSitting(posture, demi), isFalse);
    });

    test('no catalogue session is compatible with any, on either side', () {
      expect(sameSitting(null, demi), isTrue);
      expect(sameSitting(posture, null), isTrue);
      expect(sameSitting(null, null), isTrue);
    });
  });

  group('recordFor', () {
    test('finds the record of the same day and catalogue session', () {
      final found = recordFor(
        [record('a', 12, sheet: 'posture-1')],
        noon,
        posture,
      );

      expect(found?.id, const SessionId('a'));
    });

    test('ignores another day', () {
      expect(
        recordFor([record('a', 11, sheet: 'posture-1')], noon, posture),
        isNull,
      );
    });

    test('ignores a record of another catalogue session', () {
      expect(
        recordFor([record('a', 12, sheet: 'posture-1')], noon, demi),
        isNull,
      );
    });

    test('takes a record without catalogue session for any session', () {
      expect(
        recordFor([record('a', 12)], noon, demi)?.id,
        const SessionId('a'),
      );
    });

    test('takes a record for a session without catalogue session', () {
      expect(
        recordFor([record('a', 12, sheet: 'posture-1')], noon, null)?.id,
        const SessionId('a'),
      );
    });

    test('prefers the exact catalogue session over the one without', () {
      final records = [
        record('free', 12),
        record('exact', 12, sheet: 'demi-bille-2'),
      ];

      expect(recordFor(records, noon, demi)?.id, const SessionId('exact'));
    });

    test('prefers an exact absence over a record with a session', () {
      final records = [
        record('with', 12, sheet: 'posture-1'),
        record('free', 12),
      ];

      expect(recordFor(records, noon, null)?.id, const SessionId('free'));
    });

    test('keeps the saving order among equally good candidates', () {
      final records = [record('first', 12), record('second', 12)];

      expect(recordFor(records, noon, demi)?.id, const SessionId('first'));
    });

    test('finds nothing without records', () {
      expect(recordFor(const [], noon, posture), isNull);
    });

    group('around midnight', () {
      test('matches the last minute of the day from its first minute', () {
        final records = [
          record('a', 12, at: DateTime(2026, 10, 12, 23, 59, 59)),
        ];

        expect(
          recordFor(records, DateTime(2026, 10, 12), null)?.id,
          const SessionId('a'),
        );
      });

      test('matches the first minute of the day from its last minute', () {
        final records = [record('b', 12, at: DateTime(2026, 10, 12))];

        expect(
          recordFor(records, DateTime(2026, 10, 12, 23, 59, 59), null)?.id,
          const SessionId('b'),
        );
      });

      test('does not match one minute after midnight of the next day', () {
        final records = [record('a', 12, at: DateTime(2026, 10, 12, 23, 59))];

        expect(recordFor(records, DateTime(2026, 10, 13, 0, 1), null), isNull);
      });

      test('does not match one minute before midnight of the day before', () {
        final records = [record('a', 12, at: DateTime(2026, 10, 12, 0, 1))];

        expect(
          recordFor(records, DateTime(2026, 10, 11, 23, 59), null),
          isNull,
        );
      });

      test('tells apart the same day of another month', () {
        final records = [record('month', 12, at: DateTime(2026, 11, 12, 17))];

        expect(recordFor(records, noon, null), isNull);
      });

      test('tells apart the same day of another year', () {
        final records = [record('year', 12, at: DateTime(2025, 10, 12, 17))];

        expect(recordFor(records, noon, null), isNull);
      });

      test('tells apart the last day of the year from the first', () {
        final records = [record('a', 31, at: DateTime(2026, 12, 31, 23, 59))];

        expect(recordFor(records, DateTime(2027), null), isNull);
      });
    });
  });
}
