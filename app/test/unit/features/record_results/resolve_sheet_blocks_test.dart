import 'package:billard_cfa/features/record_results/domain/resolve_sheet_blocks.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';
import '../../../support/session_sheet_fixtures.dart';

void main() {
  final resolve = ResolveSheetBlocks(
    FixtureSessionSheetRepository(catalogueFixture()),
  );

  test('gives no block without a catalogue session', () async {
    expect(await resolve(null), SheetBlocks.none);
  });

  test(
    'gives the block of the session and the previous different block',
    () async {
      expect(
        await resolve(SheetId('demi-bille-2')),
        const SheetBlocks(main: 'demi-bille', recall: 'posture'),
      );
    },
  );

  test('has no recall block for the first session', () async {
    expect(
      await resolve(SheetId('posture-1')),
      const SheetBlocks(main: 'posture'),
    );
  });

  group('SheetBlocks.resolve', () {
    const derived = SheetBlocks(main: 'b', recall: 'a');

    test('takes the derived blocks when none is given', () {
      expect(derived.resolve(), (main: 'b', recall: 'a'));
      expect(SheetBlocks.none.resolve(), (main: null, recall: null));
    });

    test('keeps the blocks given over the derived ones', () {
      expect(derived.resolve(main: 'c'), (main: 'c', recall: 'a'));
      expect(derived.resolve(recall: 'c'), (main: 'b', recall: 'c'));
    });

    test('ignores a derived recall equal to the main block retained', () {
      expect(derived.resolve(main: 'a'), (main: 'a', recall: null));
    });
  });

  test('refuses a session unknown to the catalogue', () {
    expect(
      () => resolve(SheetId('inconnue-9')),
      violation(InvariantCode.unknownSheet),
    );
  });
}
