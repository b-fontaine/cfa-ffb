import 'dart:math' as math;
import 'dart:math' show Point;

import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/printable_text.dart';
import 'package:billard_cfa/features/export_sheet/domain/results_sheets_input.dart';
import 'package:billard_cfa/features/export_sheet/domain/results_template.dart';
import 'package:billard_cfa/features/export_sheet/domain/text_measure.dart';
import 'package:billard_cfa/features/export_sheet/domain/text_wrap.dart';

// Mise en page des fiches résultats (ADR 0021) : la fiche fédérale `[S]`
// reproduite, quatre grilles par page A4. Les libellés fixes viennent de
// `ResultsLabels` (langue de l'interface) ; ici, seules les dimensions.

const _fillGrids = 8;

/// Part de la hauteur d'un texte au-dessus de sa ligne de base (Calibri, la
/// police de la fiche fédérale, dont les positions sont mesurées par le haut).
const _baselineShare = 0.78;

/// Corps du texte des libellés, des valeurs préremplies et de l'axe.
const _labelSize = 8.5;
const _valueSize = 6.5;
const _scaleSize = 6.0;
const _legendSize = 7.0;
const _nameSize = 9.0;
const _minNameSize = 5.5;

/// Les fiches résultats de [input] : une série par exercice, chacune sur de
/// nouvelles pages ; les blocs vides de la dernière page restent vides.
PrintDocument layoutResultsSheets(
  ResultsSheetsInput input,
  TextMeasure measure,
) {
  final columns = ResultsTemplate.clampColumns(input.columns);
  final labels = input.labels;
  String p(String text) =>
      printable(text, measure, thetaWord: labels.thetaWord);
  final names = [for (final n in input.names) p(n)];
  final grids = names.isEmpty ? _fillGrids : names.length;
  final pages = <PrintPage>[];
  for (final series in input.series) {
    final printed = _PrintableSeries(series, p);
    for (var first = 0; first < grids; first += ResultsTemplate.blocksPerPage) {
      final items = <PrintItem>[..._pageFurniture(labels)];
      for (var slot = 0; slot < ResultsTemplate.blocksPerPage; slot++) {
        final index = first + slot;
        items.addAll(
          _block(
            slot: slot,
            columns: columns,
            series: printed,
            name: index < names.length ? names[index] : null,
            labels: labels,
            measure: measure,
          ),
        );
      }
      pages.add(
        PrintPage(
          width: ResultsTemplate.pageWidth,
          height: ResultsTemplate.pageHeight,
          items: items,
        ),
      );
    }
  }
  return PrintDocument(
    title: p(input.title),
    language: labels.language,
    pages: pages,
  );
}

class _PrintableSeries {
  _PrintableSeries(ResultsSeries series, String Function(String) p)
    : session = p(series.session),
      exercise = p(series.exercise),
      notion = p(series.notion),
      technique = p(series.technique),
      attempts = series.attempts;

  final String session;
  final String exercise;
  final String notion;
  final String technique;
  final int? attempts;
}

double _baseline(double top, double boxHeight) =>
    top + boxHeight * _baselineShare;

/// Titre, onglet vertical et source : identiques sur chaque page.
List<PrintItem> _pageFurniture(ResultsLabels labels) => [
  PrintText(
    x: 42.6,
    y: 31.5,
    text: labels.title,
    size: 12,
    style: PrintFontStyle.bold,
    tag: 'title',
  ),
  const PrintRect(
    x: ResultsTemplate.tabX,
    y: ResultsTemplate.tabY,
    width: ResultsTemplate.tabWidth,
    height: ResultsTemplate.tabHeight,
    fill: PrintShade.darkGray,
    tag: 'tab',
  ),
  PrintText(
    x: 561,
    y: 567,
    text: labels.tabBrand,
    size: 12,
    style: PrintFontStyle.bold,
    rotated: true,
    tag: 'tab-text',
  ),
  PrintText(
    x: 560,
    y: 692,
    text: labels.tabTitle,
    size: 9,
    style: PrintFontStyle.bold,
    shade: PrintShade.white,
    rotated: true,
    tag: 'tab-text',
  ),
  PrintText(
    x: ResultsTemplate.labelX,
    y: 796,
    text: labels.sourceLine,
    size: 6.5,
    shade: PrintShade.darkGray,
    tag: 'source',
  ),
  PrintText(
    x: ResultsTemplate.labelX,
    y: 805,
    text: labels.notFederalLine,
    size: 6.5,
    shade: PrintShade.darkGray,
    tag: 'source',
  ),
];

/// Un bloc (en-tête et grille) à la position [slot] de la page (0 à 3, ligne
/// par ligne), avec le nom [name] (`null` : vierge).
List<PrintItem> _block({
  required int slot,
  required int columns,
  required _PrintableSeries series,
  required String? name,
  required ResultsLabels labels,
  required TextMeasure measure,
}) {
  final dx =
      (slot % ResultsTemplate.blocksPerRow) * ResultsTemplate.blockPitchX;
  final dy =
      (slot ~/ ResultsTemplate.blocksPerRow) * ResultsTemplate.blockPitchY;
  final colWidth = ResultsTemplate.columnWidth(columns);
  final headSize = colWidth >= 30 ? 8.0 : 6.5;
  Point<double> point(double x, double y) => Point(x + dx, y + dy);
  PrintLine headerRule(double x1, double y1, double x2, double y2) => PrintLine(
    from: point(x1, y1),
    to: point(x2, y2),
    width: 0.9,
    tag: 'header-rule',
  );
  // En-tête : cases « ESSAI n » et case « Nb de billes empochées ».
  final items = <PrintItem>[
    headerRule(
      ResultsTemplate.gridLeft,
      ResultsTemplate.headerTop,
      ResultsTemplate.gridLeft + ResultsTemplate.gridWidth,
      ResultsTemplate.headerTop,
    ),
    headerRule(
      ResultsTemplate.boxLeft,
      ResultsTemplate.headerMiddle,
      ResultsTemplate.boxRight,
      ResultsTemplate.headerMiddle,
    ),
    headerRule(
      ResultsTemplate.boxLeft,
      ResultsTemplate.headerBottom,
      ResultsTemplate.boxRight,
      ResultsTemplate.headerBottom,
    ),
    headerRule(
      ResultsTemplate.boxLeft,
      ResultsTemplate.headerMiddle,
      ResultsTemplate.boxLeft,
      ResultsTemplate.headerBottom,
    ),
    headerRule(
      ResultsTemplate.boxRight,
      ResultsTemplate.headerMiddle,
      ResultsTemplate.boxRight,
      ResultsTemplate.headerBottom,
    ),
  ];
  for (var i = 0; i <= columns; i++) {
    final x = ResultsTemplate.gridLeft + i * colWidth;
    items.add(
      PrintLine(
        from: point(x, ResultsTemplate.headerTop),
        to: point(x, ResultsTemplate.headerBottom),
        width: 0.9,
        tag: 'column-rule',
      ),
    );
  }
  items.add(
    PrintText(
      x: ResultsTemplate.labelX + dx,
      y: _baseline(62.64, 11.04) + dy,
      text: labels.name,
      size: _labelSize,
      tag: 'name-label',
    ),
  );
  if (name != null) items.add(_nameText(name, dx, dy, measure));
  items
    ..add(
      PrintText(
        x: ResultsTemplate.labelX + dx,
        y: _baseline(90.62, 11.04) + dy,
        text: labels.totalFirstLine,
        size: _labelSize,
        tag: 'total-label',
      ),
    )
    ..add(
      PrintText(
        x: ResultsTemplate.labelX + dx,
        y: _baseline(103.94, 11.04) + dy,
        text: labels.totalSecondLine,
        size: _labelSize,
        tag: 'total-label',
      ),
    );
  final total = series.attempts == null ? '/….' : '/${series.attempts}';
  for (var i = 0; i < columns; i++) {
    final center = ResultsTemplate.gridLeft + (i + 0.5) * colWidth;
    items
      ..add(
        PrintText(
          x: center + dx,
          y: _baseline(62.64, 11.04) + dy,
          text: labels.attempt,
          size: headSize,
          align: PrintAlign.center,
          tag: 'attempt-head',
        ),
      )
      ..add(
        PrintText(
          x: center + dx,
          y: _baseline(76.08, 11.04) + dy,
          text: '${i + 1}',
          size: headSize,
          align: PrintAlign.center,
          tag: 'attempt-head',
        ),
      )
      ..add(
        PrintText(
          x: ResultsTemplate.gridLeft + (i + 1) * colWidth - 3.5 + dx,
          y: _baseline(103.94, 11.04) + dy,
          text: total,
          size: headSize,
          align: PrintAlign.right,
          tag: 'attempt-total',
        ),
      );
  }

  // Grille : 17 bandes, de 16 en haut à 0 en bas.
  for (var band = 0; band <= ResultsTemplate.bands; band++) {
    final y = ResultsTemplate.gridTop + band * ResultsTemplate.bandHeight;
    final edge = band == ResultsTemplate.bands;
    items.add(
      PrintLine(
        from: point(ResultsTemplate.gridLeft, y),
        to: point(ResultsTemplate.gridLeft + ResultsTemplate.gridWidth, y),
        width: edge ? 0.9 : 0.5,
        shade: edge ? PrintShade.black : PrintShade.lightGray,
        tag: 'band-rule',
      ),
    );
  }
  for (var i = 0; i <= columns; i++) {
    final x = ResultsTemplate.gridLeft + i * colWidth;
    items.add(
      PrintLine(
        from: point(x, ResultsTemplate.gridTop),
        to: point(x, ResultsTemplate.gridBottom),
        width: i == 0 ? 0.9 : 0.5,
        shade: i == 0 ? PrintShade.black : PrintShade.lightGray,
        tag: 'column-rule',
      ),
    );
  }
  for (var value = ResultsTemplate.scaleMax; value >= 0; value--) {
    items.add(
      PrintText(
        x: ResultsTemplate.gridLeft - 3.9 + dx,
        y: ResultsTemplate.bandCenter(value) + _scaleSize * 0.35 + dy,
        text: '$value',
        size: _scaleSize,
        align: PrintAlign.right,
        tag: 'scale-label',
      ),
    );
  }
  for (var i = 0; i < columns; i++) {
    items.add(
      PrintText(
        x: ResultsTemplate.gridLeft + (i + 0.5) * colWidth + dx,
        y: _baseline(374.78, 9) + dy,
        text: labels.attemptLegend(i + 1),
        size: _legendSize,
        align: PrintAlign.center,
        tag: 'attempt-legend',
      ),
    );
  }
  items.addAll(_leftColumn(series, labels, dx, dy, measure));
  return items;
}

/// Le prénom dans la case « Nom : » : réduit s'il est trop large, puis coupé
/// avec une ellipse.
PrintText _nameText(String name, double dx, double dy, TextMeasure measure) {
  const x = 44.0;
  const room = ResultsTemplate.gridLeft - 3 - x;
  var size = _nameSize;
  var text = name;
  final natural = measure.width(text, size, PrintFontStyle.regular);
  if (natural > room) {
    size = math.max(_minNameSize, size * room / natural);
    if (measure.width(text, size, PrintFontStyle.regular) > room) {
      var cut = text.length;
      while (cut > 1 &&
          measure.width(
                '${text.substring(0, cut)}…',
                size,
                PrintFontStyle.regular,
              ) >
              room) {
        cut--;
      }
      text = '${text.substring(0, cut)}…';
    }
  }
  return PrintText(
    x: x + dx,
    y: _baseline(62.64, 11.04) + dy,
    text: text,
    size: size,
    tag: 'student-name',
  );
}

/// Colonne de gauche : les libellés de la séance, de l'exercice, de la notion
/// et de la technique, suivis de leur valeur, dans la largeur laissée libre à
/// gauche de l'axe.
List<PrintItem> _leftColumn(
  _PrintableSeries series,
  ResultsLabels labels,
  double dx,
  double dy,
  TextMeasure measure,
) {
  final items = <PrintItem>[];
  var y = _baseline(130.58, 11.04);
  void field(String label, String value) {
    items.add(
      PrintText(
        x: ResultsTemplate.labelX + dx,
        y: y + dy,
        text: label,
        size: _labelSize,
        tag: 'prefill-label',
      ),
    );
    y += _valueSize + 2.5;
    for (final line in wrapText(
      value,
      ResultsTemplate.leftColumnWidth,
      _valueSize,
      PrintFontStyle.regular,
      measure,
    )) {
      items.add(
        PrintText(
          x: ResultsTemplate.labelX + dx,
          y: y + dy,
          text: line,
          size: _valueSize,
          tag: 'prefill',
        ),
      );
      y += _valueSize + 1.2;
    }
    y += 6;
  }

  field(labels.session, series.session);
  field(labels.exercise, series.exercise);
  field(labels.notion, series.notion);
  field(labels.technique, series.technique);
  return items;
}
