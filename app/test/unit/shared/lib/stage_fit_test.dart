import 'package:billard_cfa/shared/lib/stage_fit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isWidthLimited', () {
    test('is true when the width, not the height, bounds the figure', () {
      // 390 de large pour un schéma 2:1 : 195 de haut, dans 700 disponibles.
      expect(isWidthLimited(width: 390, height: 700, aspect: 2), isTrue);
    });

    test('is false when the height bounds the figure', () {
      // 1280 de large mais 300 de haut : le schéma tient par la hauteur.
      expect(isWidthLimited(width: 1280, height: 300, aspect: 2), isFalse);
    });

    test('is true when the figure just fits (equal ratio)', () {
      expect(isWidthLimited(width: 400, height: 200, aspect: 2), isTrue);
    });

    test('is false a hair above the ratio', () {
      expect(isWidthLimited(width: 400.01, height: 200, aspect: 2), isFalse);
    });

    test('handles a square zone and a square figure', () {
      expect(isWidthLimited(width: 300, height: 300, aspect: 1), isTrue);
    });

    test('handles a very wide figure in a tall zone', () {
      expect(isWidthLimited(width: 100, height: 900, aspect: 4), isTrue);
    });

    test('handles a very tall figure in a wide zone', () {
      expect(isWidthLimited(width: 900, height: 100, aspect: 0.25), isFalse);
    });

    test('refuses a non-positive ratio', () {
      expect(
        () => isWidthLimited(width: 1, height: 1, aspect: 0),
        throwsArgumentError,
      );
    });
  });
}
