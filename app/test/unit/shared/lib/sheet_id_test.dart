import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';

void main() {
  test('accepts a technique and a part as a slug', () {
    expect(SheetId('demi-bille-2').value, 'demi-bille-2');
  });

  test('is equal by value and usable in sets', () {
    expect(SheetId('puissance-1'), SheetId('puissance-1'));
    expect(SheetId('puissance-1').hashCode, SheetId('puissance-1').hashCode);
    expect({SheetId('a-1'), SheetId('a-1')}, hasLength(1));
    expect(SheetId('a-1') == SheetId('a-2'), isFalse);
  });

  test('prints its value', () {
    expect(SheetId('coule-3').toString(), 'coule-3');
  });

  for (final bad in [
    '',
    '  ',
    'Demi-bille-1',
    'demi_bille',
    '-a',
    'a-',
    'a--b',
  ]) {
    test('refuses the malformed identifier "$bad"', () {
      expect(() => SheetId(bad), violation(InvariantCode.invalidSheet));
    });
  }

  test('tryParse returns null instead of throwing', () {
    expect(SheetId.tryParse('rebond-bande-1'), SheetId('rebond-bande-1'));
    expect(SheetId.tryParse('Rebond'), isNull);
    expect(SheetId.tryParse(null), isNull);
  });
}
