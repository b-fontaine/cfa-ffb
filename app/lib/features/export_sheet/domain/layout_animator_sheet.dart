import 'dart:math' as math;
import 'dart:math' show Point;

import 'package:billard_cfa/features/export_sheet/domain/diagram_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_labels.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/printable_text.dart';
import 'package:billard_cfa/features/export_sheet/domain/sheet_print_input.dart';
import 'package:billard_cfa/features/export_sheet/domain/text_measure.dart';
import 'package:billard_cfa/features/export_sheet/domain/text_wrap.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';

// Mise en page de la feuille de l'animateur (ADR 0021) : A4 portrait, marges de
// 15 mm, déroulé minuté puis une section par étape, sources et pied de page.
// La pagination se fait par blocs insécables : un titre reste avec ce qui le
// suit, un schéma n'est jamais coupé, un paragraphe plus haut qu'une page se
// coupe entre ses lignes.

const _pageWidth = 595.0;
const _pageHeight = 842.0;
const _margin = 42.5;
const double _contentWidth = _pageWidth - 2 * _margin;

/// Bas de la zone de contenu (le pied de page est en dessous).
const _bottom = 790.0;
const _footerRuleY = 798.0;
const _footerBaseline = 812.0;

const _titleSize = 16.0;
const _headerSize = 10.0;
const _sectionSize = 12.0;
const _phaseSize = 9.0;
const _stepSize = 11.0;
const _bodySize = 9.0;
const _smallSize = 8.0;
const _footerSize = 7.0;

/// Hauteur d'une ligne, en part du corps.
const _leading = 1.3;

/// Colonne des libellés : les paragraphes à libellé ont le texte en retrait.
const _labelColumn = 105.0;
const double _labelWidth = _labelColumn - 6;
const _bulletIndent = 10.0;

const _diagramWidth = 300.0;

/// Marge au-dessus et au-dessous d'un schéma : plus que le rayon d'une poche.
const _diagramMargin = 9.0;
const _legendGap = 12.0;

/// Colonnes du déroulé (abscisses relatives à la marge gauche).
const _colTime = 0.0;
const _colStep = 52.0;
const _colMinutes = 440.0;
const _colSource = 458.0;

/// La feuille de l'animateur de [input] : un document de pages A4.
PrintDocument layoutAnimatorSheet(SheetPrintInput input, TextMeasure measure) {
  final builder = _Builder(input.labels, measure)..build(input);
  return PrintDocument(
    title: builder.p(input.title),
    language: input.language,
    pages: builder.pages(input),
  );
}

/// Un élément insécable : sa hauteur (écart final compris) et son dessin à
/// partir de l'ordonnée de son haut.
class _Atom {
  const _Atom(this.height, this.draw, {this.keepWithNext = false});

  final double height;
  final List<PrintItem> Function(double top) draw;
  final bool keepWithNext;
}

String _mark(Provenance source) => switch (source) {
  Provenance.s => '[S]',
  Provenance.ffb => '[FFB]',
  Provenance.web => '[Web]',
  Provenance.prop => '[Prop]',
};

class _Builder {
  _Builder(this._labels, this._measure);

  final PrintLabels _labels;
  final TextMeasure _measure;
  final List<_Atom> _atoms = [];

  String p(String text) =>
      printable(text, _measure, thetaWord: _labels.thetaWord);

  double _lineHeight(double size) => size * _leading;

  List<String> _wrap(
    String text,
    double width,
    double size,
    PrintFontStyle style,
  ) => wrapText(p(text), width, size, style, _measure);

  void build(SheetPrintInput input) {
    _addHeader(input);
    _addRundown(input);
    _addSteps(input);
    _addSources(input);
  }

  // --- Atomes ---

  /// Lignes de texte au même corps, à partir de [x] ; coupé en blocs de
  /// quelques dizaines de lignes au plus pour qu'un bloc tienne toujours dans
  /// une page.
  void _lines(
    List<String> lines, {
    required double x,
    required double size,
    required String tag,
    PrintFontStyle style = PrintFontStyle.regular,
    PrintShade shade = PrintShade.black,
    double gap = 3,
    bool keepWithNext = false,
    PrintAlign align = PrintAlign.left,
  }) {
    final lh = _lineHeight(size);
    final chunk = math.max(1, ((_bottom - _margin) / lh).floor() - 2);
    for (var start = 0; start < lines.length; start += chunk) {
      final part = lines.sublist(start, math.min(lines.length, start + chunk));
      final last = start + chunk >= lines.length;
      _atoms.add(
        _Atom(
          part.length * lh + (last ? gap : 0),
          (top) => [
            for (final (i, line) in part.indexed)
              PrintText(
                x: x,
                y: top + i * lh + size * 0.85,
                text: line,
                size: size,
                style: style,
                shade: shade,
                align: align,
                tag: tag,
              ),
          ],
          keepWithNext: keepWithNext && last,
        ),
      );
    }
  }

  void _addHeader(SheetPrintInput input) {
    _lines(
      _wrap(input.title, _contentWidth, _titleSize, PrintFontStyle.bold),
      x: _margin,
      size: _titleSize,
      style: PrintFontStyle.bold,
      tag: 'title',
      gap: 4,
      keepWithNext: true,
    );
    for (final line in input.headerLines) {
      _lines(
        _wrap(line, _contentWidth, _headerSize, PrintFontStyle.regular),
        x: _margin,
        size: _headerSize,
        tag: 'header',
        gap: 1,
      );
    }
    _gap(8);
  }

  void _gap(double height) => _atoms.add(_Atom(height, (_) => const []));

  void _section(String title) {
    _lines(
      _wrap(title, _contentWidth, _sectionSize, PrintFontStyle.bold),
      x: _margin,
      size: _sectionSize,
      style: PrintFontStyle.bold,
      tag: 'section-heading',
      gap: 4,
      keepWithNext: true,
    );
  }

  // --- Déroulé ---

  void _addRundown(SheetPrintInput input) {
    _section(_labels.rundown);
    const headSize = _smallSize;
    final head = [
      (_labels.columnTime, _margin + _colTime, PrintAlign.left),
      (_labels.columnStep, _margin + _colStep, PrintAlign.left),
      (_labels.columnMinutes, _margin + _colMinutes, PrintAlign.right),
    ];
    _atoms.add(
      _Atom(
        _lineHeight(headSize) + 3,
        (top) => [
          for (final (text, x, align) in head)
            PrintText(
              x: x,
              y: top + headSize * 0.85,
              text: p(text),
              size: headSize,
              style: PrintFontStyle.bold,
              align: align,
              tag: 'rundown-head',
            ),
          PrintLine(
            from: Point(_margin, top + _lineHeight(headSize) + 0.5),
            to: Point(
              _margin + _contentWidth,
              top + _lineHeight(headSize) + 0.5,
            ),
            tag: 'rundown-rule',
          ),
        ],
        keepWithNext: true,
      ),
    );
    var start = 0;
    const stepWidth = _colMinutes - _colStep - 24;
    for (final step in input.steps) {
      final from = start;
      start += step.minutes;
      final to = start;
      final lines = _wrap(
        step.title,
        stepWidth,
        _bodySize,
        PrintFontStyle.regular,
      );
      final rows = math.max(1, lines.length);
      _atoms.add(
        _Atom(rows * _lineHeight(_bodySize) + 2, (top) {
          final y = top + _bodySize * 0.85;
          final mark = step.source;
          return [
            PrintText(
              x: _margin + _colTime,
              y: y,
              text: '$from–$to',
              size: _bodySize,
              tag: 'rundown-time',
            ),
            for (final (i, line) in lines.indexed)
              PrintText(
                x: _margin + _colStep,
                y: y + i * _lineHeight(_bodySize),
                text: line,
                size: _bodySize,
                tag: 'rundown-step',
              ),
            PrintText(
              x: _margin + _colMinutes,
              y: y,
              text: '${step.minutes}',
              size: _bodySize,
              align: PrintAlign.right,
              tag: 'rundown-minutes',
            ),
            if (mark != null)
              PrintText(
                x: _margin + _colSource,
                y: y,
                text: _mark(mark),
                size: _smallSize,
                shade: PrintShade.darkGray,
                tag: 'rundown-source',
              ),
          ];
        }),
      );
    }
    _atoms.add(
      _Atom(
        _lineHeight(_bodySize) + 4,
        (top) => [
          PrintLine(
            from: Point(_margin, top + 0.5),
            to: Point(_margin + _contentWidth, top + 0.5),
            tag: 'rundown-rule',
          ),
          PrintText(
            x: _margin + _colMinutes,
            y: top + 2 + _bodySize * 0.85,
            text: p(_labels.total(start)),
            size: _bodySize,
            style: PrintFontStyle.bold,
            align: PrintAlign.right,
            tag: 'rundown-total',
          ),
        ],
      ),
    );
    _lines(
      _wrap(
        _labels.minutesNote,
        _contentWidth,
        _smallSize,
        PrintFontStyle.italic,
      ),
      x: _margin,
      size: _smallSize,
      style: PrintFontStyle.italic,
      shade: PrintShade.darkGray,
      tag: 'rundown-note',
      gap: 10,
    );
  }

  // --- Étapes ---

  void _addSteps(SheetPrintInput input) {
    String? phase;
    for (final step in input.steps) {
      if (step.phase != phase) {
        phase = step.phase;
        // Une étape qui porte le nom de sa phase (« Bilan ») ne le répète pas.
        if (step.title == step.phase) {
          _addStep(step);
          continue;
        }
        _lines(
          _wrap(step.phase, _contentWidth, _phaseSize, PrintFontStyle.bold),
          x: _margin,
          size: _phaseSize,
          style: PrintFontStyle.bold,
          shade: PrintShade.darkGray,
          tag: 'phase-heading',
          gap: 2,
          keepWithNext: true,
        );
      }
      _addStep(step);
    }
  }

  void _addStep(SheetPrintStep step) {
    final mark = step.source;
    final heading = mark == null ? step.title : '${step.title} ${_mark(mark)}';
    final lines = _wrap(
      heading,
      _contentWidth - 50,
      _stepSize,
      PrintFontStyle.bold,
    );
    final lh = _lineHeight(_stepSize);
    _atoms.add(
      _Atom(
        lines.length * lh + 3,
        (top) => [
          for (final (i, line) in lines.indexed)
            PrintText(
              x: _margin,
              y: top + i * lh + _stepSize * 0.85,
              text: line,
              size: _stepSize,
              style: PrintFontStyle.bold,
              tag: 'step-heading',
            ),
          PrintText(
            x: _margin + _contentWidth,
            y: top + _stepSize * 0.85,
            text: _labels.minutes(step.minutes),
            size: _bodySize,
            style: PrintFontStyle.bold,
            shade: PrintShade.darkGray,
            align: PrintAlign.right,
            tag: 'step-minutes',
          ),
          PrintLine(
            from: Point(_margin, top + lines.length * lh + 0.5),
            to: Point(_margin + _contentWidth, top + lines.length * lh + 0.5),
            width: 0.4,
            shade: PrintShade.lightGray,
            tag: 'step-rule',
          ),
        ],
        keepWithNext: true,
      ),
    );
    for (final block in step.blocks) {
      switch (block) {
        case SheetPrintText():
          _addText(block);
        case SheetPrintList():
          _addList(block);
        case SheetPrintDiagram():
          _addDiagram(block);
        case SheetPrintCaption():
          _addCaption(block);
      }
    }
    _gap(8);
  }

  void _addText(SheetPrintText block) {
    final text = block.proposal ? '${block.text} [Prop]' : block.text;
    final label = block.label;
    if (label == null) {
      _lines(
        _wrap(text, _contentWidth, _bodySize, PrintFontStyle.regular),
        x: _margin,
        size: _bodySize,
        tag: 'text',
      );
      return;
    }
    _labelled(
      label,
      _wrap(
        text,
        _contentWidth - _labelColumn,
        _bodySize,
        PrintFontStyle.regular,
      ),
      bullets: false,
    );
  }

  void _addList(SheetPrintList block) {
    final label = block.label;
    final width =
        _contentWidth - (label == null ? 0 : _labelColumn) - _bulletIndent;
    final wrapped = [
      for (final item in block.items)
        _wrap(item, width, _bodySize, PrintFontStyle.regular),
    ];
    _labelled(
      label,
      wrapped.expand((lines) => lines).toList(),
      bullets: true,
      groups: [for (final lines in wrapped) lines.length],
    );
  }

  /// Paragraphe (ou liste) avec libellé en retrait : libellé gras à gauche,
  /// texte dans la colonne de droite. [groups] : nombre de lignes de chaque
  /// puce.
  void _labelled(
    String? label,
    List<String> lines, {
    required bool bullets,
    List<int>? groups,
  }) {
    final lh = _lineHeight(_bodySize);
    final labelLines = label == null
        ? const <String>[]
        : _wrap(label, _labelWidth, _bodySize, PrintFontStyle.bold);
    final textX = _margin + (label == null ? 0 : _labelColumn);
    final rows = math.max(lines.length, labelLines.length);
    final chunk = math.max(1, ((_bottom - _margin) / lh).floor() - 2);
    for (var start = 0; start < rows; start += chunk) {
      final end = math.min(rows, start + chunk);
      final last = end >= rows;
      _atoms.add(
        _Atom((end - start) * lh + (last ? 3 : 0), (top) {
          final items = <PrintItem>[];
          for (var row = start; row < end; row++) {
            final y = top + (row - start) * lh + _bodySize * 0.85;
            if (row < labelLines.length) {
              items.add(
                PrintText(
                  x: _margin,
                  y: y,
                  text: labelLines[row],
                  size: _bodySize,
                  style: PrintFontStyle.bold,
                  tag: 'label',
                ),
              );
            }
            if (row < lines.length) {
              final bulletRow = bullets && _startsGroup(groups!, row);
              if (bulletRow) {
                items.add(
                  PrintText(
                    x: textX,
                    y: y,
                    text: '•',
                    size: _bodySize,
                    tag: 'bullet',
                  ),
                );
              }
              items.add(
                PrintText(
                  x: textX + (bullets ? _bulletIndent : 0),
                  y: y,
                  text: lines[row],
                  size: _bodySize,
                  tag: 'text',
                ),
              );
            }
          }
          return items;
        }),
      );
    }
  }

  /// Vrai quand la ligne [row] ouvre une puce (premier rang de son groupe).
  bool _startsGroup(List<int> groups, int row) {
    var first = 0;
    for (final size in groups) {
      if (row == first) return true;
      first += math.max(1, size);
      if (row < first) return false;
    }
    return false;
  }

  void _addCaption(SheetPrintCaption block) {
    _lines(
      _wrap(
        block.caption,
        _contentWidth,
        _smallSize + 0.5,
        PrintFontStyle.italic,
      ),
      x: _margin,
      size: _smallSize + 0.5,
      style: PrintFontStyle.italic,
      tag: 'caption',
      gap: 1,
      keepWithNext: true,
    );
    _lines(
      _wrap(
        '${_labels.illustrationAlt} ${block.alt}',
        _contentWidth,
        _smallSize,
        PrintFontStyle.regular,
      ),
      x: _margin,
      size: _smallSize,
      shade: PrintShade.darkGray,
      tag: 'caption-alt',
      gap: 4,
    );
  }

  void _addDiagram(SheetPrintDiagram block) {
    const legendWidth = _contentWidth - _diagramWidth - _legendGap;
    const captionSize = _smallSize + 0.5;
    const descriptionSize = 7.0;
    final caption = _wrap(
      block.caption,
      legendWidth,
      captionSize,
      PrintFontStyle.bold,
    );
    final description = block.description == null
        ? const <String>[]
        : _wrap(
            block.description!,
            legendWidth,
            descriptionSize,
            PrintFontStyle.italic,
          );
    final balls = _wrap(
      _labels.ballLegend,
      legendWidth,
      _smallSize,
      PrintFontStyle.regular,
    );
    const tableHeight = _diagramWidth / 2;
    final legendHeight =
        caption.length * _lineHeight(captionSize) +
        description.length * _lineHeight(descriptionSize) +
        balls.length * _lineHeight(_smallSize) +
        9;
    // Les poches débordent de la table de leur rayon : la marge les dégage du
    // texte qui précède et de celui qui suit.
    const margin = _diagramMargin;
    _atoms.add(
      _Atom(math.max(tableHeight, legendHeight) + 2 * margin, (top) {
        final drawing = drawDiagram(
          block.table,
          x: _margin,
          y: top + margin,
          width: _diagramWidth,
          measure: _measure,
        );
        const x = _margin + _diagramWidth + _legendGap;
        var y = top + margin;
        final items = <PrintItem>[...drawing.items];
        void write(
          List<String> lines,
          double size,
          PrintFontStyle style,
          String tag, {
          PrintShade shade = PrintShade.black,
        }) {
          for (final line in lines) {
            items.add(
              PrintText(
                x: x,
                y: y + size * 0.85,
                text: line,
                size: size,
                style: style,
                shade: shade,
                tag: tag,
              ),
            );
            y += _lineHeight(size);
          }
          y += 3;
        }

        write(caption, captionSize, PrintFontStyle.bold, 'diagram-caption');
        write(
          description,
          descriptionSize,
          PrintFontStyle.italic,
          'diagram-description',
        );
        write(
          balls,
          _smallSize,
          PrintFontStyle.regular,
          'diagram-legend',
          shade: PrintShade.darkGray,
        );
        return items;
      }),
    );
  }

  // --- Sources ---

  void _addSources(SheetPrintInput input) {
    if (input.sources.isNotEmpty) {
      _section(_labels.sources);
      for (final source in input.sources) {
        _lines(
          _wrap(
            source,
            _contentWidth - _bulletIndent,
            _smallSize + 0.5,
            PrintFontStyle.regular,
          ),
          x: _margin + _bulletIndent,
          size: _smallSize + 0.5,
          tag: 'source-line',
          gap: 1.5,
        );
      }
      _gap(6);
    }
    if (input.uncertainties.isNotEmpty) {
      _section(_labels.uncertainties);
      for (final item in input.uncertainties) {
        _lines(
          _wrap(
            item,
            _contentWidth - _bulletIndent,
            _smallSize - 0.5,
            PrintFontStyle.regular,
          ),
          x: _margin + _bulletIndent,
          size: _smallSize - 0.5,
          shade: PrintShade.darkGray,
          tag: 'uncertainty',
          gap: 1.5,
        );
      }
    }
  }

  // --- Pagination ---

  List<PrintPage> pages(SheetPrintInput input) {
    final pages = <List<PrintItem>>[<PrintItem>[]];
    var y = _margin;
    var i = 0;
    while (i < _atoms.length) {
      // Un titre reste avec ce qui le suit : on mesure toute la chaîne.
      var need = _atoms[i].height;
      var j = i;
      while (_atoms[j].keepWithNext && j + 1 < _atoms.length) {
        j++;
        need += _atoms[j].height;
      }
      if (y + need > _bottom && y > _margin) {
        pages.add(<PrintItem>[]);
        y = _margin;
      }
      final atom = _atoms[i];
      pages.last.addAll(atom.draw(y));
      y += atom.height;
      i++;
    }
    final count = pages.length;
    return [
      for (final (index, items) in pages.indexed)
        PrintPage(
          width: _pageWidth,
          height: _pageHeight,
          items: [...items, ..._footer(input, index + 1, count)],
        ),
    ];
  }

  List<PrintItem> _footer(SheetPrintInput input, int page, int pages) => [
    const PrintLine(
      from: Point(_margin, _footerRuleY),
      to: Point(_margin + _contentWidth, _footerRuleY),
      width: 0.4,
      shade: PrintShade.lightGray,
      tag: 'footer-rule',
    ),
    PrintText(
      x: _margin,
      y: _footerBaseline,
      text: p(input.shortTitle),
      size: _footerSize,
      shade: PrintShade.darkGray,
      tag: 'footer-title',
    ),
    PrintText(
      x: _margin + _contentWidth / 2,
      y: _footerBaseline,
      text: p(_labels.proposalLegend),
      size: _footerSize,
      shade: PrintShade.darkGray,
      align: PrintAlign.center,
      tag: 'footer-legend',
    ),
    PrintText(
      x: _margin + _contentWidth,
      y: _footerBaseline,
      text: p(_labels.pageOf(page, pages)),
      size: _footerSize,
      shade: PrintShade.darkGray,
      align: PrintAlign.right,
      tag: 'footer-page',
    ),
  ];
}
