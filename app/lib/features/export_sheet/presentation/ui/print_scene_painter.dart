import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:flutter/material.dart';

/// Peint une page de la scène d'impression à l'écran (aperçu, ADR 0021) : la
/// même scène que celle du PDF, à l'échelle de la largeur disponible. Le texte
/// est dessiné avec la fonte de l'application (Exo 2) ; l'écart de largeur avec
/// le PDF reste de quelques points, la coupure des lignes est identique.
class PrintScenePainter extends CustomPainter {
  const PrintScenePainter(this.page, {this.fontFamily});

  final PrintPage page;
  final String? fontFamily;

  static const _black = Color(0xFF000000);
  static const _darkGray = Color(0xFF545454);
  static const _lightGray = Color(0xFFADADAD);
  static const _white = Color(0xFFFFFFFF);

  static Color color(PrintShade shade) => switch (shade) {
    PrintShade.black => _black,
    PrintShade.darkGray => _darkGray,
    PrintShade.lightGray => _lightGray,
    PrintShade.white => _white,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / page.width;
    canvas.drawRect(Offset.zero & size, Paint()..color = _white);
    for (final item in page.items) {
      switch (item) {
        case PrintText():
          _text(canvas, item, scale);
        case PrintLine():
          _stroke(
            canvas,
            Path()
              ..moveTo(item.from.x * scale, item.from.y * scale)
              ..lineTo(item.to.x * scale, item.to.y * scale),
            item.shade,
            item.width * scale,
            item.dash,
            scale,
          );
        case PrintPolyline():
          if (item.points.length < 2) continue;
          final path = Path()
            ..moveTo(item.points.first.x * scale, item.points.first.y * scale);
          for (final p in item.points.skip(1)) {
            path.lineTo(p.x * scale, p.y * scale);
          }
          _stroke(
            canvas,
            path,
            item.shade,
            item.width * scale,
            item.dash,
            scale,
          );
        case PrintRect():
          final rect = Rect.fromLTWH(
            item.x * scale,
            item.y * scale,
            item.width * scale,
            item.height * scale,
          );
          _paint(
            canvas,
            Path()..addRect(rect),
            item.fill,
            item.stroke,
            item.strokeWidth * scale,
            item.dash,
            scale,
          );
        case PrintCircle():
          _paint(
            canvas,
            Path()..addOval(
              Rect.fromCircle(
                center: Offset(item.center.x * scale, item.center.y * scale),
                radius: item.radius * scale,
              ),
            ),
            item.fill,
            item.stroke,
            item.strokeWidth * scale,
            item.dash,
            scale,
          );
        case PrintPolygon():
          if (item.points.length < 3) continue;
          final path = Path()
            ..moveTo(item.points.first.x * scale, item.points.first.y * scale);
          for (final p in item.points.skip(1)) {
            path.lineTo(p.x * scale, p.y * scale);
          }
          canvas.drawPath(path..close(), Paint()..color = color(item.fill));
      }
    }
  }

  void _text(Canvas canvas, PrintText item, double scale) {
    final bold =
        item.style == PrintFontStyle.bold ||
        item.style == PrintFontStyle.boldItalic;
    final italic =
        item.style == PrintFontStyle.italic ||
        item.style == PrintFontStyle.boldItalic;
    final painter = TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: item.size * scale,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: color(item.shade),
          height: 1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final left = switch (item.align) {
      PrintAlign.left => 0.0,
      PrintAlign.center => -painter.width / 2,
      PrintAlign.right => -painter.width,
    };
    canvas
      ..save()
      ..translate(item.x * scale, item.y * scale);
    if (item.rotated) canvas.rotate(math.pi / 2);
    painter.paint(canvas, Offset(left, -baseline));
    canvas.restore();
    painter.dispose();
  }

  void _paint(
    Canvas canvas,
    Path path,
    PrintShade? fill,
    PrintShade? stroke,
    double width,
    List<double> dash,
    double scale,
  ) {
    if (fill != null) {
      canvas.drawPath(path, Paint()..color = color(fill));
    }
    if (stroke != null) _stroke(canvas, path, stroke, width, dash, scale);
  }

  void _stroke(
    Canvas canvas,
    Path path,
    PrintShade shade,
    double width,
    List<double> dash,
    double scale,
  ) {
    final paint = Paint()
      ..color = color(shade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(width, 0.5)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      dash.length < 2 ? path : _dashed(path, [for (final d in dash) d * scale]),
      paint,
    );
  }

  /// Le tracé [source] découpé selon la suite « longueur tracée, longueur
  /// vide » de [dash].
  Path _dashed(Path source, List<double> dash) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var index = 0;
      while (distance < metric.length) {
        final length = dash[index % dash.length];
        if (index.isEven) {
          out.addPath(
            metric.extractPath(
              distance,
              math.min(distance + length, metric.length),
            ),
            Offset.zero,
          );
        }
        distance += length;
        index++;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(PrintScenePainter oldDelegate) =>
      oldDelegate.page != page || oldDelegate.fontFamily != fontFamily;
}
