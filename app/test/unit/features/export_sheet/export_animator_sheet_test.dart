import 'dart:convert';

import 'package:billard_cfa/features/export_sheet/domain/export_animator_sheet.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_labels.dart';
import 'package:billard_cfa/features/export_sheet/domain/sheet_print_input.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_print_renderer.dart';
import '../../../support/fixed_text_measure.dart';

final _labels = PrintLabels(
  rundown: 'Run-down',
  columnTime: 'Time',
  columnStep: 'Step',
  columnMinutes: 'Min',
  total: (m) => 'Total: $m min',
  minutesNote: 'Minutes are [Prop]',
  proposalLegend: '[Prop]: proposal',
  sources: 'Sources',
  uncertainties: 'To check',
  illustrationAlt: 'Description:',
  ballLegend: 'R red',
  pageOf: (page, pages) => '$page / $pages',
  minutes: (m) => '$m min',
  thetaWord: 'thêta',
);

SheetPrintInput _input({String text = 'Une consigne'}) => SheetPrintInput(
  fileName: 'seance-x-enfants.pdf',
  title: 'Titre',
  shortTitle: 'Titre',
  language: 'fr',
  headerLines: const ['Enfants, 90 min'],
  steps: [
    SheetPrintStep(
      phase: 'Phase',
      title: 'Étape',
      minutes: 5,
      blocks: [SheetPrintText(text)],
    ),
  ],
  sources: const [],
  labels: _labels,
);

void main() {
  test('lays out, renders and names the document', () async {
    final renderer = FakePrintRenderer();

    final result = await ExportAnimatorSheet(renderer)(_input());

    final document = (result as Ok<ExportedDocument>).value;
    expect(document.fileName, 'seance-x-enfants.pdf');
    expect(document.document.pages, hasLength(1));
    expect(utf8.decode(document.bytes), 'PDF 1');
    expect(renderer.rendered.single, same(document.document));
  });

  test('measures the text with the measure of the renderer', () async {
    // Une chasse plus large fait passer le paragraphe sur plus de lignes.
    final narrow = FakePrintRenderer();
    final wide = FakePrintRenderer(measure: const FixedTextMeasure(em: 5));
    final text = List.filled(60, 'mot').join(' ');

    await ExportAnimatorSheet(narrow)(_input(text: text));
    await ExportAnimatorSheet(wide)(_input(text: text));

    int lines(FakePrintRenderer r) => r.rendered.single.pages
        .expand((p) => p.items)
        .where((i) => i.tag == 'text')
        .length;
    expect(lines(wide), greaterThan(lines(narrow)));
  });

  test('refuses a content the font cannot print, without rendering', () async {
    final renderer = FakePrintRenderer(
      measure: const FixedTextMeasure(missing: {0x2713}),
    );

    final result = await ExportAnimatorSheet(renderer)(_input(text: 'fait ✓'));

    expect(
      (result as Err<ExportedDocument>).failure,
      isA<InvariantViolation>().having(
        (e) => e.code,
        'code',
        InvariantCode.unprintableContent,
      ),
    );
    expect(renderer.rendered, isEmpty);
  });
}
