import 'package:billard_cfa/features/export_sheet/domain/layout_results_sheets.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/results_sheets_input.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_export_source.dart';
import '../../../support/fixed_text_measure.dart';

const _measure = FixedTextMeasure();

ResultsSeries _series({
  String session = 'Quantité demi-bille',
  String exercise = '1. Les six parts de gâteau',
  String notion = 'Viser la tangente',
  String technique = 'Quantité demi-bille',
  int? attempts = 10,
}) => ResultsSeries(
  session: session,
  exercise: exercise,
  notion: notion,
  technique: technique,
  attempts: attempts,
);

ResultsSheetsInput _input({
  List<ResultsSeries>? series,
  List<String> names = const [],
  int columns = 5,
  ResultsLabels? labels,
}) => ResultsSheetsInput(
  title: 'Fiches résultats',
  series: series ?? [_series()],
  names: names,
  columns: columns,
  labels: labels ?? testResultsLabels(),
);

PrintDocument _layout(ResultsSheetsInput input) =>
    layoutResultsSheets(input, _measure);

Iterable<PrintText> _texts(PrintPage page, [String? tag]) =>
    page.items.whereType<PrintText>().where((t) => tag == null || t.tag == tag);

void main() {
  group('pages', () {
    test('without names, eight blank grids make two pages', () {
      expect(_layout(_input()).pages, hasLength(2));
    });

    test('four names make one page', () {
      final document = _layout(_input(names: ['A', 'B', 'C', 'D']));

      expect(document.pages, hasLength(1));
    });

    test('five names round up to eight grids, two pages', () {
      final document = _layout(_input(names: ['A', 'B', 'C', 'D', 'E']));

      expect(document.pages, hasLength(2));
    });

    test('nine names make three pages', () {
      final document = _layout(
        _input(names: [for (var i = 0; i < 9; i++) 'E$i']),
      );

      expect(document.pages, hasLength(3));
    });

    test('every page is A4 portrait', () {
      for (final page in _layout(_input()).pages) {
        expect(page.width, closeTo(595, 0.1));
        expect(page.height, closeTo(842, 0.1));
      }
    });

    test('each series starts on a new page', () {
      final document = _layout(
        _input(
          series: [
            _series(exercise: '1. A'),
            _series(exercise: '2. B'),
          ],
          names: ['A', 'B'],
        ),
      );

      expect(document.pages, hasLength(2));
      expect(_texts(document.pages[0]).map((t) => t.text), contains('1. A'));
      expect(_texts(document.pages[1]).map((t) => t.text), contains('2. B'));
    });

    test('the title and the language are carried over', () {
      final document = _layout(_input());

      expect(document.title, 'Fiches résultats');
      expect(document.language, 'fr');
    });
  });

  group('federal template', () {
    test('every page has four grids with the federal name label', () {
      for (final page in _layout(_input()).pages) {
        final labels = _texts(page, 'name-label').toList();

        expect(labels.map((t) => t.text), List.filled(4, 'Nom :'));
        expect(labels.map((t) => t.x), [
          closeTo(14.4, 0.1),
          closeTo(14.4 + 268.25, 0.6),
          closeTo(14.4, 0.1),
          closeTo(14.4 + 268.25, 0.6),
        ]);
        expect(labels.map((t) => t.y), [
          closeTo(71.2, 1.5),
          closeTo(71.2, 1.5),
          closeTo(71.2 + 381.8, 1.5),
          closeTo(71.2 + 381.8, 1.5),
        ]);
      }
    });

    test('five ESSAI columns, numbered 1 to 5, in each of the four grids', () {
      final page = _layout(_input()).pages.first;
      final heads = _texts(page, 'attempt-head').map((t) => t.text).toList();

      expect(heads, [
        for (var i = 0; i < 4; i++)
          for (var k = 1; k <= 5; k++) ...['ESSAI', '$k'],
      ]);
    });

    test('six columns when six passes are required', () {
      final page = _layout(_input(columns: 6)).pages.first;
      final heads = _texts(page, 'attempt-head').map((t) => t.text);

      expect(heads.where((t) => t == 'ESSAI'), hasLength(24));
      expect(heads, contains('6'));
    });

    test('the columns are clamped between three and eight', () {
      final few = _layout(_input(columns: 1)).pages.first;
      final many = _layout(_input(columns: 20)).pages.first;

      expect(
        _texts(few, 'attempt-head').where((t) => t.text == 'ESSAI'),
        hasLength(12),
      );
      expect(
        _texts(many, 'attempt-head').where((t) => t.text == 'ESSAI'),
        hasLength(32),
      );
    });

    test('the scale runs from 0 to 16 in each grid, 0 at the bottom', () {
      final page = _layout(_input()).pages.first;
      final labels = _texts(page, 'scale-label').toList();

      expect(labels, hasLength(4 * 17));
      final first = labels.take(17).toList();
      expect(first.map((t) => t.text).toSet(), {
        for (var n = 0; n <= 16; n++) '$n',
      });
      final zero = first.firstWhere((t) => t.text == '0');
      final sixteen = first.firstWhere((t) => t.text == '16');
      expect(zero.y, greaterThan(sixteen.y));
      expect(zero.y, closeTo(366.5, 3));
      expect(sixteen.y, closeTo(138.3, 3));
    });

    test('the attempt legends read essai 1 to essai 5 under each grid', () {
      final page = _layout(_input()).pages.first;
      final legends = _texts(page, 'attempt-legend').map((t) => t.text);

      expect(legends, [
        for (var i = 0; i < 4; i++)
          for (var k = 1; k <= 5; k++) 'essai $k',
      ]);
    });

    test('the vertical rules of the grid sit at the federal columns', () {
      final page = _layout(_input()).pages.first;
      final rules =
          page.items
              .whereType<PrintLine>()
              .where((l) => l.tag == 'column-rule' && l.from.x < 280)
              .map((l) => l.from.x)
              .toSet()
              .toList()
            ..sort();

      expect(rules, [
        closeTo(85.8, 0.3),
        closeTo(118.3, 0.3),
        closeTo(150.8, 0.3),
        closeTo(183.2, 0.3),
        closeTo(215.9, 0.3),
        closeTo(248.4, 0.3),
      ]);
    });

    test('the header box ends where the grid ends, like the federal sheet', () {
      final page = _layout(_input()).pages.first;
      final middle = page.items
          .whereType<PrintLine>()
          .where(
            (l) =>
                l.tag == 'header-rule' &&
                l.from.y == l.to.y &&
                (l.from.y - 87.8).abs() < 0.2 &&
                l.from.x < 100,
          )
          .single;

      expect(middle.from.x, closeTo(11.2, 0.2));
      expect(middle.to.x, closeTo(248.4, 0.3));
    });

    test('the page title, the tab and the source are on every page', () {
      for (final page in _layout(_input()).pages) {
        final texts = _texts(page).map((t) => t.text).toList();

        expect(texts, contains('Fiche Résultats'));
        expect(texts, contains('BLACKBALL'));
        expect(texts, contains('FICHE RESULTATS'));
        expect(
          texts.join(' '),
          contains(
            'Fiche Résultats CFA Blackball, Direction Technique Nationale',
          ),
        );
        expect(texts.join(' '), contains('[S]'));
      }
    });

    test('the tab text is vertical', () {
      final page = _layout(_input()).pages.first;

      expect(
        _texts(page).where((t) => t.text == 'BLACKBALL').single.rotated,
        isTrue,
      );
    });
  });

  group('printable text', () {
    const missing = FixedTextMeasure(missing: {0x03b8, 0x2713});

    PrintDocument layout(ResultsSheetsInput input) =>
        layoutResultsSheets(input, missing);

    test('spells theta in the prefilled values and in the names', () {
      final document = layout(
        _input(
          series: [_series(notion: 'angle θ', technique: 'θ-technique')],
          names: ['Aθ'],
        ),
      );
      final texts = document.pages.first.items
          .whereType<PrintText>()
          .map((t) => t.text)
          .join(' ');

      expect(texts, contains('angle thêta'));
      expect(texts, contains('thêta-technique'));
      expect(texts, contains('Athêta'));
      expect(texts, isNot(contains('θ')));
    });

    test('spells theta in the session and the exercise as well', () {
      final document = layout(
        _input(
          series: [_series(session: 'θ1', exercise: '1. θ2')],
        ),
      );
      final texts = document.pages.first.items
          .whereType<PrintText>()
          .map((t) => t.text)
          .join(' ');

      expect(texts, contains('thêta1'));
      expect(texts, contains('thêta2'));
    });

    test('refuses what the font cannot draw, with the document title', () {
      expect(
        () => layout(_input(series: [_series(notion: 'fait ✓')])),
        throwsA(isA<InvariantViolation>()),
      );
      expect(
        () => layout(
          ResultsSheetsInput(
            title: 'Fiche ✓',
            series: [_series()],
            labels: testResultsLabels(),
          ),
        ),
        throwsA(isA<InvariantViolation>()),
      );
      expect(
        () => layout(_input(names: ['Zoé ✓'])),
        throwsA(isA<InvariantViolation>()),
      );
    });

    test('spells theta in the document title', () {
      final document = layout(
        ResultsSheetsInput(
          title: 'Fiche θ',
          series: [_series()],
          labels: testResultsLabels(),
        ),
      );

      expect(document.title, 'Fiche thêta');
    });
  });

  group('labels', () {
    ResultsLabels english() => ResultsLabels(
      language: 'en',
      title: 'Results sheet',
      tabBrand: 'BLACKBALL',
      tabTitle: 'RESULTS SHEET',
      sourceLine: 'Source [S]: CFA Blackball Results Sheet (grid reproduced).',
      notFederalLine: 'Produced by the app: not a federal document.',
      name: 'Name:',
      totalFirstLine: 'Balls',
      totalSecondLine: 'pocketed',
      attempt: 'TRY',
      attemptLegend: (n) => 'try $n',
      session: 'Session:',
      exercise: 'Exercise:',
      notion: 'Notion:',
      technique: 'Technique:',
      thetaWord: 'theta',
    );

    test('every fixed text comes from the labels, none is hard-coded', () {
      final document = _layout(_input(labels: english()));
      final texts = _texts(document.pages.first).map((t) => t.text).toList();

      expect(
        texts,
        containsAll([
          'Results sheet',
          'BLACKBALL',
          'RESULTS SHEET',
          'Name:',
          'Balls',
          'pocketed',
          'TRY',
          'try 1',
          'Session:',
          'Exercise:',
          'Notion:',
          'Technique:',
        ]),
      );
      final joined = texts.join(' ');
      for (final french in [
        'Fiche',
        'Nom :',
        'ESSAI',
        'essai',
        'Séance :',
        'Exercice :',
        'billes',
        'empochées',
        'fédéral',
      ]) {
        expect(joined, isNot(contains(french)), reason: french);
      }
      expect(joined, contains('Source [S]: CFA Blackball'));
      expect(joined, contains('not a federal document'));
    });

    test('the document language is the one of the labels', () {
      expect(_layout(_input(labels: english())).language, 'en');
    });

    test('theta is spelled with the word of the labels', () {
      const missing = FixedTextMeasure(missing: {0x03b8});
      final document = layoutResultsSheets(
        _input(
          series: [_series(notion: 'angle θ')],
          labels: english(),
        ),
        missing,
      );
      final texts = _texts(document.pages.first).map((t) => t.text).join(' ');

      expect(texts, contains('angle theta'));
      expect(texts, isNot(contains('thêta')));
    });
  });

  group('contents', () {
    test('the session, exercise, notion and technique are prefilled', () {
      final page = _layout(_input()).pages.first;
      final texts = _texts(page).map((t) => t.text).toList();

      expect(texts, containsAll(['Séance :', 'Exercice :', 'Notion :']));
      expect(texts, contains('Technique :'));
      expect(texts.join(' '), contains('Séance : Quantité demi-bille'));
      expect(texts.join(' '), contains('Notion : Viser la tangente'));
    });

    test('long values are wrapped inside the left column', () {
      final page = _layout(
        _input(series: [_series(notion: 'Viser la tangente de la bille')]),
      ).pages.first;

      for (final text in _texts(page, 'prefill').where((t) => t.x < 280)) {
        expect(
          text.x + text.text.length * text.size * 0.5,
          lessThanOrEqualTo(14.4 + 58.6 + 0.01),
          reason: text.text,
        );
      }
    });

    test('the denominator is the number of attempts of the success rate', () {
      final page = _layout(_input()).pages.first;
      final slots = _texts(page, 'attempt-total').map((t) => t.text);

      expect(slots, List.filled(20, '/10'));
    });

    test('the denominator is left blank without a success rate', () {
      final page = _layout(_input(series: [_series(attempts: null)]))
          .pages
          .first;
      final slots = _texts(page, 'attempt-total').map((t) => t.text);

      expect(slots, List.filled(20, '/….'));
    });

    test('names are blank by default', () {
      final page = _layout(_input()).pages.first;

      expect(_texts(page, 'student-name'), isEmpty);
    });

    test('names fill the grids in the order given', () {
      final document = _layout(_input(names: ['Léa', 'Zoé', 'Hugo']));
      final names = _texts(document.pages.first, 'student-name').toList();

      expect(names.map((t) => t.text), ['Léa', 'Zoé', 'Hugo']);
      expect(names[0].x, lessThan(names[1].x));
      expect(names[2].y, greaterThan(names[0].y));
    });

    test(
      'a name too wide for its cell is shrunk, then cut with an ellipsis',
      () {
        final document = _layout(
          _input(names: ['Anne-Marie-Charlotte-Joséphine-Dupont']),
        );
        final name = _texts(document.pages.first, 'student-name').single;

        expect(name.size, lessThan(9));
        expect(name.text, endsWith('…'));
        expect(name.text.length, lessThan(37));
      },
    );

    test('the page holds no image item', () {
      for (final page in _layout(_input()).pages) {
        for (final item in page.items) {
          expect(
            item,
            anyOf(isA<PrintText>(), isA<PrintLine>(), isA<PrintRect>()),
          );
        }
      }
    });
  });
}
