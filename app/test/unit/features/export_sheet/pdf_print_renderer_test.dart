import 'dart:convert';
import 'dart:math' show Point;

import 'package:billard_cfa/features/export_sheet/data/pdf_print_renderer.dart';
import 'package:billard_cfa/features/export_sheet/domain/layout_results_sheets.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_renderer.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/results_sheets_input.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_export_source.dart';

PrintDocument _document(List<PrintPage> pages) =>
    PrintDocument(title: 'Titre du fichier', language: 'fr', pages: pages);

PrintPage _page({
  double width = 300,
  double height = 400,
  List<PrintItem> items = const [],
}) => PrintPage(width: width, height: height, items: items);

/// Le fichier non compressé, lu comme du texte (l'en-tête et le dessin des
/// pages sont lisibles ; les polices sont en ASCII85).
String _text(List<int> bytes) => latin1.decode(bytes);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PrintSession session;

  setUp(() async {
    session = await PdfPrintRenderer.configured(compress: false).open();
  });

  Future<String> render(List<PrintPage> pages) async =>
      _text(await session.render(_document(pages)));

  group('measure', () {
    test('widens with the number of characters and the size', () {
      final measure = session.measure;
      final one = measure.width('mot', 10, PrintFontStyle.regular);

      expect(one, greaterThan(0));
      expect(
        measure.width('mot mot', 10, PrintFontStyle.regular),
        greaterThan(one),
      );
      expect(
        measure.width('mot', 20, PrintFontStyle.regular),
        closeTo(2 * one, 1e-9),
      );
    });

    test('gives a width in points close to the real Exo 2 advance', () {
      // « i » est étroit, « M » large : proportions réelles de la fonte.
      final i = session.measure.width('i', 100, PrintFontStyle.regular);
      final m = session.measure.width('M', 100, PrintFontStyle.regular);

      expect(i, lessThan(m / 2));
      expect(m, inInclusiveRange(60, 100));
    });

    test('is zero for the empty text', () {
      expect(session.measure.width('', 10, PrintFontStyle.regular), 0);
    });

    test('measures the italic with its own font', () {
      final regular = session.measure.width(
        'Quantité de bille',
        10,
        PrintFontStyle.regular,
      );
      final italic = session.measure.width(
        'Quantité de bille',
        10,
        PrintFontStyle.italic,
      );

      expect(italic, isNot(regular));
    });

    test('knows the glyphs of French and refuses theta and the check mark', () {
      final measure = session.measure;

      for (final char in 'éèêàçœ«»°…—≥'.runes) {
        expect(
          measure.hasGlyph(char),
          isTrue,
          reason: String.fromCharCode(char),
        );
      }
      expect(measure.hasGlyph(0x03b8), isFalse);
      expect(measure.hasGlyph(0x2713), isFalse);
    });
  });

  group('file', () {
    test('is a PDF with its title and without any link', () async {
      final pdf = await render([_page()]);

      expect(pdf, startsWith('%PDF-'));
      expect(pdf.trimRight(), endsWith('%%EOF'));
      expect(pdf, contains('/Title(Titre du fichier)'));
      expect(pdf, isNot(contains('/URI')));
      expect(pdf, isNot(contains('/Launch')));
    });

    test(
      'has one page per page of the scene, in order, with its size',
      () async {
        final pdf = await render([
          _page(),
          _page(width: 400, height: 500),
          _page(width: 500, height: 600),
        ]);

        final sizes = RegExp(r'/MediaBox\[0 0 (\d+) (\d+)\]')
            .allMatches(pdf)
            .map((m) => '${m[1]}x${m[2]}')
            .toList();
        expect(sizes, ['300x400', '400x500', '500x600']);
        expect(RegExp('/Type/Page(?![a-z])').allMatches(pdf), hasLength(3));
        expect(pdf, contains('/Count 3'));
      },
    );

    test('embeds the font', () async {
      final pdf = await render([
        _page(
          items: const [PrintText(x: 10, y: 20, text: 'Bonjour', size: 12)],
        ),
      ]);

      expect(pdf, contains('/FontFile2'));
      expect(pdf, contains('/BaseFont/Exo2-Regular'));
    });

    test('keeps the text searchable through the unicode map', () async {
      final pdf = await render([
        _page(items: const [PrintText(x: 10, y: 20, text: 'Aé', size: 12)]),
      ]);

      // Table ToUnicode : U+0041 « A » et U+00E9 « é ».
      expect(pdf, contains('<0041>'));
      expect(pdf, contains('<00E9>'));
    });

    test('stays small for a full results sheet', () async {
      final document = layoutResultsSheets(
        ResultsSheetsInput(
          title: 'Fiches',
          labels: testResultsLabels(),
          series: const [
            ResultsSeries(
              session: 'Quantité demi-bille',
              exercise: '1. Les six parts de gâteau',
              notion: 'Viser la tangente',
              technique: 'Quantité demi-bille',
              attempts: 10,
            ),
          ],
          names: const ['Léa', 'Zoé', 'Hugo', 'Inès', 'Noé'],
        ),
        session.measure,
      );

      final bytes = await PdfPrintRenderer.configured().open().then(
        (s) => s.render(document),
      );

      expect(bytes.length, lessThan(400 * 1024));
      expect(
        RegExp('/Type/Page(?![a-z])')
            .allMatches(_text(await session.render(document))),
        hasLength(2),
      );
    });
  });

  group('drawing', () {
    test(
      'flips the vertical axis : the origin of the scene is the top left',
      () async {
        final pdf = await render([
          _page(
            items: const [
              PrintCircle(
                center: Point(100, 100),
                radius: 5,
                fill: PrintShade.black,
              ),
            ],
          ),
        ]);

        // Page de 400 de haut : le centre (100, 100) devient (100, 300) ; le
        // contour du cercle commence au point bas (100, 295).
        expect(pdf, contains('100 295 m'));
      },
    );

    test('draws a rectangle from its top left corner', () async {
      final pdf = await render([
        _page(
          items: const [
            PrintRect(
              x: 5,
              y: 6,
              width: 10,
              height: 20,
              stroke: PrintShade.black,
            ),
          ],
        ),
      ]);

      expect(pdf, contains('5 374 10 20 re'));
    });

    test('draws dashes and resets them for the next item', () async {
      final pdf = await render([
        _page(
          items: const [
            PrintLine(from: Point(0, 0), to: Point(100, 100), dash: [3, 2]),
            PrintLine(from: Point(0, 0), to: Point(50, 50)),
          ],
        ),
      ]);

      expect(pdf, contains('[3 2] 0 d'));
      expect(pdf, contains('[] 0 d'));
    });

    test(
      'simulates the bold with a thin outline and leaves the regular alone',
      () async {
        final bold = await render([
          _page(
            items: const [
              PrintText(
                x: 10,
                y: 20,
                text: 'Gras',
                size: 12,
                style: PrintFontStyle.bold,
              ),
            ],
          ),
        ]);
        final regular = await render([
          _page(items: const [PrintText(x: 10, y: 20, text: 'Gras', size: 12)]),
        ]);

        expect(bold, contains('2 Tr'));
        expect(regular, isNot(contains('Tr')));
      },
    );

    test('turns a vertical text a quarter turn to the right', () async {
      final pdf = await render([
        _page(
          items: const [
            PrintText(x: 10, y: 40, text: 'Haut', size: 12, rotated: true),
          ],
        ),
      ]);

      expect(pdf, contains('0 -1 1 0 10 360 cm'));
    });

    test(
      'aligns a centred text on its middle and a right one on its end',
      () async {
        Future<double> x(PrintAlign align) async {
          final pdf = await render([
            _page(
              items: [
                PrintText(
                  x: 100,
                  y: 20,
                  text: 'Centre',
                  size: 12,
                  align: align,
                ),
              ],
            ),
          ]);
          return double.parse(
            RegExp(r'([\d.]+) 380 Td').firstMatch(pdf)!.group(1)!,
          );
        }

        final width = session.measure.width(
          'Centre',
          12,
          PrintFontStyle.regular,
        );
        expect(await x(PrintAlign.left), 100);
        expect(await x(PrintAlign.center), closeTo(100 - width / 2, 0.01));
        expect(await x(PrintAlign.right), closeTo(100 - width, 0.01));
      },
    );

    test('draws an arrow head as a filled polygon', () async {
      final pdf = await render([
        _page(
          items: const [
            PrintPolygon(points: [Point(10, 10), Point(20, 10), Point(15, 20)]),
          ],
        ),
      ]);

      expect(pdf, contains('10 390 m'));
      expect(pdf, contains('20 390 l'));
      expect(pdf, contains('15 380 l'));
    });
  });
}
