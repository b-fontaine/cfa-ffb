import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/text_wrap.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixed_text_measure.dart';

void main() {
  // Chaque caractère fait 5 points (taille 10, chasse 0,5).
  const measure = FixedTextMeasure();

  List<String> wrap(String text, double width) =>
      wrapText(text, width, 10, PrintFontStyle.regular, measure);

  group('wrapText', () {
    test('keeps a line that fits exactly', () {
      expect(wrap('abcd efgh', 45), ['abcd efgh']);
    });

    test('wraps one point before the exact width', () {
      expect(wrap('abcd efgh', 44.9), ['abcd', 'efgh']);
    });

    test('wraps at spaces and never leaves a leading or trailing space', () {
      expect(wrap('un deux trois quatre', 50), ['un deux', 'trois', 'quatre']);
    });

    test('collapses repeated spaces', () {
      expect(wrap('a    b', 100), ['a b']);
    });

    test('breaks a word longer than the line, character by character', () {
      expect(wrap('abcdefghij', 20), ['abcd', 'efgh', 'ij']);
    });

    test('puts what is left after a long word on its own line start', () {
      expect(wrap('xy abcdefghij z', 20), ['xy', 'abcd', 'efgh', 'ij z']);
    });

    test('keeps explicit line breaks', () {
      expect(wrap('ab\ncd', 100), ['ab', 'cd']);
    });

    test('keeps an empty line between two paragraphs', () {
      expect(wrap('ab\n\ncd', 100), ['ab', '', 'cd']);
    });

    test('gives no line for the empty text', () {
      expect(wrap('', 100), isEmpty);
    });

    test('measures with the style given', () {
      final lines = wrapText('abcd efgh', 45, 10, PrintFontStyle.bold, measure);

      expect(lines, ['abcd efgh']);
    });

    test('measures each style with its own width', () {
      const bold = _BoldIsWider();
      final regular = wrapText(
        'abcd efgh',
        45,
        10,
        PrintFontStyle.regular,
        bold,
      );
      final heavy = wrapText('abcd efgh', 45, 10, PrintFontStyle.bold, bold);

      expect(regular, ['abcd efgh']);
      expect(heavy, ['abcd', 'efgh']);
    });

    test('never loops on a width smaller than one character', () {
      expect(wrap('abc', 1), ['a', 'b', 'c']);
    });
  });
}

/// Mesure dont le gras est deux fois plus large que le maigre.
class _BoldIsWider extends FixedTextMeasure {
  const _BoldIsWider();

  @override
  double width(String text, double size, PrintFontStyle style) =>
      super.width(text, size, style) * (style == PrintFontStyle.bold ? 2 : 1);
}
