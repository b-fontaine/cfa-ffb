import 'package:billard_cfa/entities/session_record/domain/record_matching.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

SessionRecord record(String id, int dayOfMonth, {String? sheet}) =>
    SessionRecord(
      id: SessionId(id),
      groupId: const GroupId('g1'),
      seasonId: const SeasonId('season'),
      date: DateTime(2026, 10, dayOfMonth, 17),
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
  });
}
