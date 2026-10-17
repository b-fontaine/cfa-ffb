import 'package:billard_cfa/features/export_sheet/domain/printable_text.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixed_text_measure.dart';

void main() {
  const measure = FixedTextMeasure(missing: {0x03b8, 0x2713, 0x2192});

  group('printable', () {
    test('keeps accents, guillemets and degrees untouched', () {
      const text = 'Œuvre « à l’œil » à 30° : très évident — ≥ 2';

      expect(printable(text, measure, thetaWord: 'thêta'), text);
    });

    test('spells theta, which the font lacks', () {
      expect(
        printable('l’angle θ vaut 30°', measure, thetaWord: 'thêta'),
        'l’angle thêta vaut 30°',
      );
    });

    test('spells theta with the word it is given', () {
      expect(printable('θ=30', measure, thetaWord: 'theta'), 'theta=30');
    });

    test('turns the non breaking spaces into plain spaces', () {
      expect(printable('a b c d', measure, thetaWord: 'thêta'), 'a b c d');
    });

    test('turns tabs and carriage returns into nothing harmful', () {
      expect(printable('a\tb\r', measure, thetaWord: 'thêta'), 'a b');
    });

    test('refuses a character the font cannot draw, naming it', () {
      expect(
        () => printable('c’est ✓ fait', measure, thetaWord: 'thêta'),
        throwsA(
          isA<InvariantViolation>()
              .having((e) => e.code, 'code', InvariantCode.unprintableContent)
              .having((e) => e.detail, 'detail', contains('U+2713')),
        ),
      );
    });

    test('refuses an arrow, which is not replaced either', () {
      expect(
        () => printable('a → b', measure, thetaWord: 'thêta'),
        throwsA(isA<InvariantViolation>()),
      );
    });

    test('accepts the empty text', () {
      expect(printable('', measure, thetaWord: 'thêta'), '');
    });

    test(
      'replaces before checking : a replaced character is never refused',
      () {
        const strict = FixedTextMeasure(missing: {0x03b8});

        expect(printable('θ', strict, thetaWord: 'thêta'), 'thêta');
      },
    );
  });
}
