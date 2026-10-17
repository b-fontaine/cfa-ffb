import 'dart:math' as math;
import 'dart:math' show Point;

import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/features/export_sheet/domain/layout_animator_sheet.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_labels.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/sheet_print_input.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixed_text_measure.dart';

const _measure = FixedTextMeasure(missing: {0x03b8});

final _labels = PrintLabels(
  rundown: 'Run-down',
  columnTime: 'Time',
  columnStep: 'Step',
  columnMinutes: 'Min',
  total: (m) => 'Total: $m min',
  minutesNote: 'Minutes are [Prop]: computed by the application.',
  proposalLegend: '[Prop]: unsourced proposal, to be validated.',
  sources: 'Sources',
  uncertainties: 'Points to check',
  illustrationAlt: 'Description:',
  ballLegend: 'R red, J yellow, N black, B white',
  pageOf: (page, pages) => '$page / $pages',
  minutes: (m) => '$m minutes',
  thetaWord: 'thêta',
);

SheetPrintStep _step(
  String title,
  int minutes, {
  Provenance? source = Provenance.s,
  List<SheetPrintBlock> blocks = const [],
}) => SheetPrintStep(
  phase: 'Phase',
  title: title,
  minutes: minutes,
  source: source,
  blocks: blocks,
);

SheetPrintInput _input({
  List<SheetPrintStep>? steps,
  List<String> sources = const ['[S] fiche.pdf, page 3'],
  List<String> uncertainties = const [],
  String title = 'Quantité demi-bille',
}) => SheetPrintInput(
  fileName: 'seance-demi-bille-1-enfants.pdf',
  title: title,
  shortTitle: 'Demi-bille',
  language: 'fr',
  headerLines: const ['Enfants, 90 min', 'Notion : viser'],
  steps: steps ?? [_step('Accueil', 5), _step('Théorie', 20), _step('Jeu', 15)],
  sources: sources,
  uncertainties: uncertainties,
  labels: _labels,
);

PrintDocument _layout(SheetPrintInput input) =>
    layoutAnimatorSheet(input, _measure);

Iterable<PrintText> _texts(PrintDocument d, [String? tag]) => d.pages
    .expand((p) => p.items)
    .whereType<PrintText>()
    .where((t) => tag == null || t.tag == tag);

String _all(PrintDocument d) => _texts(d).map((t) => t.text).join(' ');

/// Un texte long : des mots de cinq lettres.
String _words(int count) => List.filled(count, 'mot12').join(' ');

void main() {
  group('document', () {
    test('is made of A4 portrait pages carrying the title and language', () {
      final document = _layout(_input());

      expect(document.title, 'Quantité demi-bille');
      expect(document.language, 'fr');
      expect(document.pages, hasLength(1));
      expect(document.pages.single.width, closeTo(595, 0.1));
      expect(document.pages.single.height, closeTo(842, 0.1));
    });

    test('opens with the title in bold and the header lines', () {
      final document = _layout(_input());
      final title = _texts(document, 'title').single;

      expect(title.text, 'Quantité demi-bille');
      expect(title.style, PrintFontStyle.bold);
      expect(_texts(document, 'header').map((t) => t.text), [
        'Enfants, 90 min',
        'Notion : viser',
      ]);
      expect(title.y, lessThan(_texts(document, 'header').first.y));
    });

    test('wraps a long title inside the margins', () {
      final document = _layout(_input(title: _words(60)));

      expect(_texts(document, 'title').length, greaterThan(1));
    });

    test('keeps every line inside the 15 mm margins', () {
      final document = _layout(
        _input(
          steps: [
            _step('Accueil', 5, blocks: [SheetPrintText(_words(300))]),
          ],
        ),
      );

      for (final text in _texts(document)) {
        if (text.align != PrintAlign.left) continue;
        final width = text.text.length * text.size * 0.5;
        expect(text.x, greaterThanOrEqualTo(42.5 - 1e-9));
        expect(
          text.x + width,
          lessThanOrEqualTo(595 - 42.5 + 1e-9),
          reason: text.text,
        );
      }
    });
  });

  group('run-down', () {
    test('lists each step with its cumulated time range', () {
      final document = _layout(_input());
      final rows = _texts(document, 'rundown-time').map((t) => t.text);

      expect(rows, ['0–5', '5–25', '25–40']);
    });

    test('prints the minutes of each step and the total', () {
      final document = _layout(_input());

      expect(_texts(document, 'rundown-minutes').map((t) => t.text), [
        '5',
        '20',
        '15',
      ]);
      expect(_texts(document, 'rundown-total').single.text, 'Total: 40 min');
    });

    test('totals 90 minutes for a children session', () {
      final document = _layout(
        _input(
          steps: [
            _step('A', 5),
            _step('B', 25),
            _step('C', 40),
            _step('D', 15),
            _step('E', 5),
          ],
        ),
      );

      expect(_texts(document, 'rundown-total').single.text, 'Total: 90 min');
      expect(_texts(document, 'rundown-time').last.text, '85–90');
    });

    test('totals 120 minutes for an adults session', () {
      final document = _layout(
        _input(steps: [_step('A', 10), _step('B', 50), _step('C', 60)]),
      );

      expect(_texts(document, 'rundown-total').single.text, 'Total: 120 min');
    });

    test(
      'marks the provenance of each row and notes that minutes are proposals',
      () {
        final document = _layout(
          _input(
            steps: [
              _step('A', 5),
              _step('B', 5, source: Provenance.prop),
              _step('C', 5, source: null),
            ],
          ),
        );

        expect(_texts(document, 'rundown-source').map((t) => t.text), [
          '[S]',
          '[Prop]',
        ]);
        expect(_all(document), contains('Minutes are [Prop]'));
      },
    );

    test('names the columns', () {
      final document = _layout(_input());

      expect(_texts(document, 'rundown-head').map((t) => t.text), [
        'Time',
        'Step',
        'Min',
      ]);
    });
  });

  group('steps', () {
    test(
      'name each phase once, and not again when the step bears its name',
      () {
        final document = _layout(
          _input(
            steps: [
              const SheetPrintStep(
                phase: 'Accueil',
                title: 'Rappel',
                minutes: 5,
              ),
              const SheetPrintStep(
                phase: 'Accueil',
                title: 'Autre',
                minutes: 5,
              ),
              const SheetPrintStep(phase: 'Bilan', title: 'Bilan', minutes: 5),
            ],
          ),
        );

        expect(_texts(document, 'phase-heading').map((t) => t.text), [
          'Accueil',
        ]);
      },
    );

    test('write a heading with the provenance mark and the minutes', () {
      final document = _layout(
        _input(steps: [_step('Théorie', 20, source: Provenance.ffb)]),
      );
      final heading = _texts(document, 'step-heading').single;

      expect(heading.text, 'Théorie [FFB]');
      expect(_texts(document, 'step-minutes').single.text, '20 minutes');
      expect(_texts(document, 'step-minutes').single.align, PrintAlign.right);
    });

    test('mark a proposed paragraph with [Prop]', () {
      final document = _layout(
        _input(
          steps: [
            _step(
              'Jeu',
              15,
              blocks: const [
                SheetPrintText(
                  'Une variante',
                  label: 'Variante',
                  proposal: true,
                ),
              ],
            ),
          ],
        ),
      );

      expect(_all(document), contains('Une variante [Prop]'));
    });

    test('put a bold label in a hanging column left of the text', () {
      final document = _layout(
        _input(
          steps: [
            _step(
              'Exo',
              15,
              blocks: const [
                SheetPrintText('Poser la blanche', label: 'Mise en place :'),
              ],
            ),
          ],
        ),
      );
      final label = _texts(document, 'label').single;
      final text = _texts(document, 'text').single;

      expect(label.text, 'Mise en place :');
      expect(label.style, PrintFontStyle.bold);
      expect(label.x, closeTo(42.5, 1e-9));
      expect(text.x, greaterThan(label.x + 90));
      expect(text.y, closeTo(label.y, 1e-9));
    });

    test('print a list with bullets, the label on the first line', () {
      final document = _layout(
        _input(
          steps: [
            _step(
              'Exo',
              15,
              blocks: const [
                SheetPrintList(['un', 'deux'], label: 'Points :'),
              ],
            ),
          ],
        ),
      );

      expect(_texts(document, 'bullet').map((t) => t.text), ['•', '•']);
      expect(_texts(document, 'text').map((t) => t.text), ['un', 'deux']);
      expect(_texts(document, 'label').single.text, 'Points :');
    });

    test('print the caption and the alternative text of an illustration', () {
      final document = _layout(
        _input(
          steps: [
            _step(
              'Théorie',
              20,
              blocks: const [
                SheetPrintCaption(caption: 'Plein et demi', alt: 'Deux billes'),
              ],
            ),
          ],
        ),
      );

      expect(_all(document), contains('Plein et demi'));
      expect(_all(document), contains('Description: Deux billes'));
    });

    test('replace theta, which the font lacks', () {
      final ok = _layout(
        _input(
          steps: [
            _step('Exo', 15, blocks: const [SheetPrintText('angle θ de 30°')]),
          ],
        ),
      );
      expect(_all(ok), contains('angle thêta de 30°'));
    });

    test('refuse a character that is neither drawn nor replaced', () {
      const strict = FixedTextMeasure(missing: {0x2713});

      expect(
        () => layoutAnimatorSheet(
          _input(
            steps: [
              _step('Exo', 15, blocks: const [SheetPrintText('fait ✓')]),
            ],
          ),
          strict,
        ),
        throwsA(
          isA<InvariantViolation>().having(
            (e) => e.code,
            'code',
            InvariantCode.unprintableContent,
          ),
        ),
      );
    });
  });

  group('diagrams', () {
    const table = DiagramTable(
      balls: [
        TableBall(
          id: 'w',
          color: TableBallColor.white,
          at: Point(2, 2),
          role: TableBallRole.cue,
        ),
      ],
    );

    test(
      'draw the table with its caption, description and ball letters legend',
      () {
        final document = _layout(
          _input(
            steps: [
              _step(
                'Exo',
                15,
                blocks: const [
                  SheetPrintDiagram(
                    table: table,
                    caption: 'Schéma 1',
                    description: 'Une blanche au centre',
                  ),
                ],
              ),
            ],
          ),
        );

        final items = document.pages.expand((p) => p.items);
        expect(
          items.whereType<PrintCircle>().where((c) => c.tag == 'pocket'),
          hasLength(6),
        );
        expect(_all(document), contains('Schéma 1'));
        expect(_all(document), contains('Une blanche au centre'));
        expect(_all(document), contains('R red, J yellow, N black, B white'));
      },
    );

    test('keep the legend and the description beside the table', () {
      final description = List.filled(40, 'mot12').join(' ');
      final document = _layout(
        _input(
          steps: [
            _step(
              'Exo',
              15,
              blocks: [
                SheetPrintDiagram(
                  table: table,
                  caption: 'Schéma',
                  description: description,
                ),
              ],
            ),
          ],
        ),
      );
      final items = document.pages.single.items;
      final frame = items.whereType<PrintRect>().singleWhere(
        (r) => r.tag == 'table',
      );
      final legend = items
          .whereType<PrintText>()
          .where((t) => (t.tag ?? '').startsWith('diagram-'))
          .toList();

      expect(legend.map((t) => t.tag).toSet(), {
        'diagram-caption',
        'diagram-description',
        'diagram-legend',
      });
      for (final line in legend) {
        expect(line.x, greaterThanOrEqualTo(frame.x + frame.width));
        expect(
          line.x + line.text.length * line.size * 0.5,
          lessThanOrEqualTo(552.5 + 1e-9),
        );
      }
    });

    test('keep the pockets clear of the text above and below the table', () {
      final document = _layout(
        _input(
          steps: [
            _step(
              'Exo',
              15,
              blocks: const [
                SheetPrintText('Avant'),
                SheetPrintDiagram(table: table, caption: 'Schéma'),
                SheetPrintText('Après'),
              ],
            ),
          ],
        ),
      );
      final items = document.pages.single.items;
      final frame = items.whereType<PrintRect>().singleWhere(
        (r) => r.tag == 'table',
      );
      final pockets = items
          .whereType<PrintCircle>()
          .where((c) => c.tag == 'pocket')
          .toList();
      final before = items.whereType<PrintText>().singleWhere(
        (t) => t.text == 'Avant',
      );
      final after = items.whereType<PrintText>().singleWhere(
        (t) => t.text == 'Après',
      );
      final top = pockets.map((c) => c.center.y - c.radius).reduce(math.min);
      final bottom = pockets.map((c) => c.center.y + c.radius).reduce(math.max);

      expect(frame.y, lessThan(frame.y + frame.height));
      // Sous les jambages de « Avant », avec une marge d'un point.
      expect(before.y + before.size * 0.25, lessThan(top - 1));
      // Le texte de « Après » : son haut (ligne de base moins le corps) est
      // sous les poches.
      expect(after.y - after.size, greaterThan(bottom));
    });

    test('never cut a table across two pages', () {
      final blocks = <SheetPrintBlock>[
        for (var i = 0; i < 12; i++)
          const SheetPrintDiagram(table: table, caption: 'Schéma'),
      ];
      final document = _layout(
        _input(steps: [_step('Exo', 15, blocks: blocks)]),
      );

      expect(document.pages.length, greaterThan(1));
      for (final page in document.pages) {
        final tables = page.items
            .whereType<PrintRect>()
            .where((r) => r.tag == 'table')
            .toList();
        final pockets = page.items
            .whereType<PrintCircle>()
            .where((c) => c.tag == 'pocket')
            .length;
        expect(pockets, 6 * tables.length);
        for (final t in tables) {
          expect(t.y + t.height, lessThanOrEqualTo(842 - 50));
        }
      }
    });
  });

  group('pagination', () {
    test('starts a new page when the content overflows', () {
      final steps = [
        for (var i = 0; i < 12; i++)
          _step('Étape $i', 5, blocks: [SheetPrintText(_words(150))]),
      ];
      final document = _layout(_input(steps: steps));

      expect(document.pages.length, greaterThan(2));
    });

    test('never leaves a heading alone at the bottom of a page', () {
      final steps = [
        for (var i = 0; i < 40; i++)
          _step('Étape $i', 5, blocks: [SheetPrintText(_words(40 + i))]),
      ];
      final document = _layout(_input(steps: steps));

      expect(document.pages.length, greaterThan(3));
      for (final page in document.pages) {
        final body =
            page.items
                .whereType<PrintText>()
                .where((t) => !(t.tag ?? '').startsWith('footer'))
                .toList()
              ..sort((a, b) => a.y.compareTo(b.y));
        expect(body, isNotEmpty);
        expect(
          body.last.tag,
          isNot(anyOf('step-heading', 'step-minutes', 'section-heading')),
          reason: body.last.text,
        );
      }
    });

    test('keeps a heading with its first block, whatever fills the page', () {
      // Une suite de remplissages de longueurs différentes : l'un d'eux
      // laisse juste la place d'un titre au bas de la page.
      for (var filler = 150; filler < 900; filler += 11) {
        final document = _layout(
          _input(
            steps: [
              _step('Remplissage', 5, blocks: [SheetPrintText(_words(filler))]),
              for (var i = 0; i < 6; i++)
                _step('Titre $i', 5, blocks: [SheetPrintText(_words(60))]),
            ],
          ),
        );

        for (final page in document.pages) {
          final body =
              page.items
                  .whereType<PrintText>()
                  .where((t) => !(t.tag ?? '').startsWith('footer'))
                  .toList()
                ..sort((a, b) => a.y.compareTo(b.y));
          expect(
            body.last.tag,
            isNot(
              anyOf(
                'step-heading',
                'step-minutes',
                'phase-heading',
                'section-heading',
              ),
            ),
            reason: 'remplissage $filler : « ${body.last.text} » est seul',
          );
        }
      }
    });

    test('splits a paragraph taller than a page between its lines', () {
      final document = _layout(
        _input(
          steps: [
            _step('Long', 5, blocks: [SheetPrintText(_words(4000))]),
          ],
        ),
      );

      expect(document.pages.length, greaterThan(2));
      for (final text in _texts(document)) {
        expect(text.y, lessThanOrEqualTo(842 - 30));
      }
    });

    test('keeps everything above the footer', () {
      final steps = [
        for (var i = 0; i < 20; i++)
          _step('Étape $i', 5, blocks: [SheetPrintText(_words(120))]),
      ];
      final document = _layout(_input(steps: steps));

      for (final page in document.pages) {
        for (final text in page.items.whereType<PrintText>()) {
          if ((text.tag ?? '').startsWith('footer')) continue;
          expect(text.y, lessThan(842 - 42), reason: text.text);
        }
      }
    });
  });

  group('footer', () {
    test('numbers the pages n / N, with the short title and the legend', () {
      final steps = [
        for (var i = 0; i < 12; i++)
          _step('Étape $i', 5, blocks: [SheetPrintText(_words(150))]),
      ];
      final document = _layout(_input(steps: steps));
      final count = document.pages.length;

      for (final (i, page) in document.pages.indexed) {
        final texts = page.items
            .whereType<PrintText>()
            .where((t) => (t.tag ?? '').startsWith('footer'))
            .map((t) => t.text)
            .toList();
        expect(texts, contains('${i + 1} / $count'));
        expect(texts, contains('Demi-bille'));
        expect(texts.join(' '), contains('[Prop]: unsourced proposal'));
      }
    });
  });

  group('sources', () {
    test('lists the sources after the steps, then the points to check', () {
      final document = _layout(
        _input(
          sources: const ['[S] a.pdf, page 1', '[FFB] b'],
          uncertainties: const ['Le schéma 3 est illisible'],
        ),
      );
      final text = _all(document);

      expect(text.indexOf('Sources'), greaterThan(text.indexOf('Jeu')));
      expect(text, contains('[S] a.pdf, page 1'));
      expect(text, contains('[FFB] b'));
      expect(
        text.indexOf('Points to check'),
        greaterThan(text.indexOf('Sources')),
      );
      expect(text, contains('Le schéma 3 est illisible'));
    });

    test('omits the points to check when there are none', () {
      expect(_all(_layout(_input())), isNot(contains('Points to check')));
    });
  });

  test('contains no student name, whatever the club holds', () {
    // L'entrée n'a aucun champ nominatif : la feuille ne peut rien en dire.
    final document = _layout(_input());

    expect(_all(document), isNot(contains('Léa')));
  });
}
