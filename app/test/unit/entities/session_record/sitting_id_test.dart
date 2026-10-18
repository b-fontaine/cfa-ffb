import 'package:billard_cfa/entities/session_record/domain/sitting_id.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const group = GroupId('g1');

  test('names the group, the day and the catalogue session', () {
    expect(
      sittingId(group, DateTime(2026, 10, 5, 18, 30), SheetId('posture-1')),
      const SessionId('g1_20261005_posture-1'),
    );
  });

  test('ignores the time of the day: two devices write the same document', () {
    final morning = sittingId(group, DateTime(2026, 10, 5, 8), SheetId('a-1'));
    final evening = sittingId(
      group,
      DateTime(2026, 10, 5, 23, 59),
      SheetId('a-1'),
    );

    expect(morning, evening);
  });

  test('differs by group, by day and by catalogue session', () {
    final base = sittingId(group, DateTime(2026, 10, 5), SheetId('a-1'));

    expect(
      sittingId(const GroupId('g2'), DateTime(2026, 10, 5), SheetId('a-1')),
      isNot(base),
    );
    expect(
      sittingId(group, DateTime(2026, 10, 6), SheetId('a-1')),
      isNot(base),
    );
    expect(
      sittingId(group, DateTime(2026, 10, 5), SheetId('a-2')),
      isNot(base),
    );
  });

  test('pads month and day, so 2026-1-11 and 2026-11-1 never collide', () {
    expect(
      sittingId(group, DateTime(2026, 1, 11), SheetId('a-1')),
      isNot(sittingId(group, DateTime(2026, 11), SheetId('a-1'))),
    );
  });

  // `_AAAAMMJJ_` (10 caractères) et la séance `a-1` (3) : le groupe fait le
  // reste.
  GroupId groupOf(int length) => GroupId('g' * length);

  test(
    'length: accepts exactly what the rules accept for a session reference',
    () {
      final id = sittingId(
        groupOf(maxSessionReferenceLength - 13),
        DateTime(2026, 10, 5),
        SheetId('a-1'),
      );

      expect(id.value, hasLength(maxSessionReferenceLength));
    },
  );

  test('length: refuses one character more, with a localised invariant', () {
    expect(
      () => sittingId(
        groupOf(maxSessionReferenceLength - 12),
        DateTime(2026, 10, 5),
        SheetId('a-1'),
      ),
      throwsA(
        isA<InvariantViolation>().having(
          (v) => v.code,
          'code',
          InvariantCode.sessionReferenceTooLong,
        ),
      ),
    );
  });

  test('length: a UUID group and a long catalogue session still fit', () {
    final id = sittingId(
      const GroupId('123e4567-e89b-12d3-a456-426614174000'),
      DateTime(2026, 10, 5),
      SheetId('demi-bille-2'),
    );

    expect(id.value.length, lessThanOrEqualTo(maxSessionReferenceLength));
  });
}
