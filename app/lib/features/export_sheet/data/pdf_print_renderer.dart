import 'dart:math' as math;

import 'package:billard_cfa/features/export_sheet/domain/print_renderer.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/text_measure.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:pdf/pdf.dart';

/// Rendu PDF de la scène d'impression (ADR 0021) avec l'API **bas niveau** du
/// paquet `pdf` (`PdfDocument`, `PdfPage`, `PdfGraphics`, `PdfTtfFont`) : seul
/// fichier de l'application à le connaître, ses widgets sont interdits par
/// `tool/architecture`.
///
/// La fonte est Exo 2 (déjà dans le build et le précache hors ligne : aucune
/// ressource ajoutée). Le fichier est une fonte variable : seule l'instance
/// par défaut s'embarque, le gras est simulé par un contour fin
/// (`PdfTextRenderingMode.fillAndStroke`). Le PDF produit n'est pas balisé
/// (limite du paquet).
@LazySingleton(as: PrintRenderer)
class PdfPrintRenderer implements PrintRenderer {
  PdfPrintRenderer() : this.configured();

  /// Rendu configuré : [bundle] d'où lire les fontes (par défaut `rootBundle` ;
  /// Widgetbook les sert sous `packages/billard_cfa/`) et [compress] (un
  /// fichier non compressé se lit en clair, utile aux tests).
  PdfPrintRenderer.configured({AssetBundle? bundle, this.compress = true})
    : _bundle = bundle ?? rootBundle;

  static const regularAsset = 'assets/fonts/Exo2.ttf';
  static const italicAsset = 'assets/fonts/Exo2-Italic.ttf';

  final AssetBundle _bundle;
  final bool compress;
  Future<(ByteData, ByteData)>? _fonts;

  Future<(ByteData, ByteData)> _load() => _fonts ??= _loadFonts();

  Future<(ByteData, ByteData)> _loadFonts() async {
    final regular = await _bundle.load(regularAsset);
    final italic = await _bundle.load(italicAsset);
    return (regular, italic);
  }

  @override
  Future<PrintSession> open() async {
    final (regular, italic) = await _load();
    return _PdfPrintSession(regular, italic, compress: compress);
  }
}

class _Fonts {
  _Fonts(PdfDocument document, ByteData regular, ByteData italic)
    : regular = PdfTtfFont(document, regular),
      italic = PdfTtfFont(document, italic);

  final PdfTtfFont regular;
  final PdfTtfFont italic;

  PdfTtfFont of(PrintFontStyle style) => switch (style) {
    PrintFontStyle.regular || PrintFontStyle.bold => regular,
    PrintFontStyle.italic || PrintFontStyle.boldItalic => italic,
  };
}

class _PdfPrintSession implements PrintSession {
  _PdfPrintSession(this._regular, this._italic, {required this.compress})
    : _measureFonts = _Fonts(PdfDocument(compress: false), _regular, _italic);

  final ByteData _regular;
  final ByteData _italic;
  final bool compress;
  final _Fonts _measureFonts;

  @override
  TextMeasure get measure => _PdfTextMeasure(_measureFonts);

  @override
  Future<List<int>> render(PrintDocument document) async {
    final pdf = PdfDocument(compress: compress);
    PdfInfo(
      pdf,
      title: document.title,
      creator: 'Billard CFA',
      producer: 'Billard CFA',
    );
    final fonts = _Fonts(pdf, _regular, _italic);
    for (final page in document.pages) {
      final pdfPage = PdfPage(
        pdf,
        pageFormat: PdfPageFormat(page.width, page.height),
      );
      final canvas = pdfPage.getGraphics();
      for (final item in page.items) {
        canvas.saveContext();
        _draw(canvas, fonts, item, page.height);
        canvas.restoreContext();
      }
    }
    final bytes = await pdf.save();
    return bytes;
  }
}

class _PdfTextMeasure implements TextMeasure {
  const _PdfTextMeasure(this._fonts);

  final _Fonts _fonts;

  @override
  double width(String text, double size, PrintFontStyle style) => text.isEmpty
      ? 0
      : _fonts.of(style).stringMetrics(text).advanceWidth * size;

  @override
  bool hasGlyph(int rune) => _fonts.regular.isRuneSupported(rune);
}

PdfColor _color(PrintShade shade) => switch (shade) {
  PrintShade.black => const PdfColor(0, 0, 0),
  PrintShade.darkGray => const PdfColor(0.33, 0.33, 0.33),
  PrintShade.lightGray => const PdfColor(0.68, 0.68, 0.68),
  PrintShade.white => const PdfColor(1, 1, 1),
};

void _draw(PdfGraphics canvas, _Fonts fonts, PrintItem item, double height) {
  double y(double value) => height - value;
  switch (item) {
    case PrintText():
      _text(canvas, fonts, item, height);
    case PrintLine():
      _stroke(canvas, item.shade, item.width, item.dash);
      canvas
        ..moveTo(item.from.x, y(item.from.y))
        ..lineTo(item.to.x, y(item.to.y))
        ..strokePath();
    case PrintPolyline():
      if (item.points.length < 2) return;
      _stroke(canvas, item.shade, item.width, item.dash);
      canvas.moveTo(item.points.first.x, y(item.points.first.y));
      for (final point in item.points.skip(1)) {
        canvas.lineTo(point.x, y(point.y));
      }
      canvas.strokePath();
    case PrintRect():
      canvas.drawRect(item.x, y(item.y + item.height), item.width, item.height);
      _paint(canvas, item.fill, item.stroke, item.strokeWidth, item.dash);
    case PrintCircle():
      canvas.drawEllipse(
        item.center.x,
        y(item.center.y),
        item.radius,
        item.radius,
      );
      _paint(canvas, item.fill, item.stroke, item.strokeWidth, item.dash);
    case PrintPolygon():
      if (item.points.length < 3) return;
      canvas
        ..setFillColor(_color(item.fill))
        ..moveTo(item.points.first.x, y(item.points.first.y));
      for (final point in item.points.skip(1)) {
        canvas.lineTo(point.x, y(point.y));
      }
      canvas
        ..closePath()
        ..fillPath();
  }
}

void _stroke(
  PdfGraphics canvas,
  PrintShade shade,
  double width,
  List<double> dash,
) {
  canvas
    ..setStrokeColor(_color(shade))
    ..setLineWidth(width)
    ..setLineCap(PdfLineCap.round)
    ..setLineJoin(PdfLineJoin.round)
    ..setLineDashPattern(dash);
}

/// Remplit et/ou contourne le chemin courant.
void _paint(
  PdfGraphics canvas,
  PrintShade? fill,
  PrintShade? stroke,
  double strokeWidth,
  List<double> dash,
) {
  if (fill != null) canvas.setFillColor(_color(fill));
  if (stroke != null) _stroke(canvas, stroke, strokeWidth, dash);
  if (fill != null && stroke != null) {
    canvas.fillAndStrokePath();
  } else if (fill != null) {
    canvas.fillPath();
  } else if (stroke != null) {
    canvas.strokePath();
  }
}

void _text(PdfGraphics canvas, _Fonts fonts, PrintText item, double height) {
  final font = fonts.of(item.style);
  final bold =
      item.style == PrintFontStyle.bold ||
      item.style == PrintFontStyle.boldItalic;
  final width = item.text.isEmpty
      ? 0.0
      : font.stringMetrics(item.text).advanceWidth * item.size;
  final left = switch (item.align) {
    PrintAlign.left => 0.0,
    PrintAlign.center => -width / 2,
    PrintAlign.right => -width,
  };
  final color = _color(item.shade);
  canvas.setFillColor(color);
  if (bold) {
    canvas
      ..setStrokeColor(color)
      ..setLineWidth(item.size * 0.025);
  }
  final mode = bold
      ? PdfTextRenderingMode.fillAndStroke
      : PdfTextRenderingMode.fill;
  if (item.rotated) {
    // Quart de tour à droite : la ligne se lit de haut en bas.
    canvas
      ..setTransform(
        Matrix4.translationValues(item.x, height - item.y, 0)
          ..rotateZ(-math.pi / 2),
      )
      ..drawString(font, item.size, item.text, left, 0, mode: mode);
  } else {
    canvas.drawString(
      font,
      item.size,
      item.text,
      item.x + left,
      height - item.y,
      mode: mode,
    );
  }
}
