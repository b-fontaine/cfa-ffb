import 'dart:math' as math;

import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/brand_colors.dart';
import 'package:flutter/material.dart';

/// Un essai de la courbe : billes empochées et objectif atteint ou non.
@immutable
class ChartPoint {
  const ChartPoint({required this.value, required this.reached});

  final int value;
  final bool reached;
}

/// Courbe de performance d'un élève sur un exercice, sur le modèle de la
/// fiche résultats fédérale : essais en abscisse, billes empochées en
/// ordonnée, ligne d'objectif.
///
/// Dessinée avec `CustomPainter` (aucune dépendance). L'information ne repose
/// jamais sur la couleur seule : un essai réussi est un disque plein, un
/// essai manqué un anneau creux ; le texte parlé résume la courbe
/// ([semanticLabel]) et la page affiche en plus la liste textuelle des essais.
class ProgressChart extends StatelessWidget {
  const ProgressChart({
    required this.points,
    required this.maxValue,
    required this.target,
    required this.semanticLabel,
    required this.axisLabelX,
    required this.axisLabelY,
    required this.targetLabel,
    this.height = 200,
    super.key,
  }) : assert(maxValue > 0, 'maxValue must be positive');

  final List<ChartPoint> points;

  /// Borne haute de l'axe des ordonnées (billes possibles).
  final int maxValue;

  /// Billes à empocher pour atteindre l'objectif.
  final int target;
  final String semanticLabel;
  final String axisLabelX;
  final String axisLabelY;
  final String targetLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand =
        theme.extension<BrandColors>() ??
        (scheme.brightness == Brightness.dark
            ? BrandColors.dark
            : BrandColors.light);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: ProgressChartPainter(
            points: points,
            maxValue: maxValue,
            target: target,
            axisLabelX: axisLabelX,
            axisLabelY: axisLabelY,
            targetLabel: targetLabel,
            lineColor: scheme.primary,
            targetColor: brand.accent,
            axisColor: scheme.outline,
            gridColor: scheme.outlineVariant,
            fillColor: scheme.surface,
            labelStyle: labelStyle ?? const TextStyle(),
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

/// Peintre de [ProgressChart] (public pour être testé).
class ProgressChartPainter extends CustomPainter {
  ProgressChartPainter({
    required this.points,
    required this.maxValue,
    required this.target,
    required this.axisLabelX,
    required this.axisLabelY,
    required this.targetLabel,
    required this.lineColor,
    required this.targetColor,
    required this.axisColor,
    required this.gridColor,
    required this.fillColor,
    required this.labelStyle,
    required this.textDirection,
  });

  final List<ChartPoint> points;
  final int maxValue;
  final int target;
  final String axisLabelX;
  final String axisLabelY;
  final String targetLabel;
  final Color lineColor;
  final Color targetColor;
  final Color axisColor;
  final Color gridColor;
  final Color fillColor;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  static const double _left = 40;
  static const double _right = AppSpacing.md;
  static const double _top = AppSpacing.md;
  static const double _bottom = 40;
  static const double _marker = 6;

  /// Position de l'essai [index] (0 à n-1) et de la valeur [value] dans
  /// [area].
  Offset position(Rect area, int index, int value) {
    final count = math.max(points.length, 1);
    final x = area.left + area.width * (index + 0.5) / count;
    final y = area.bottom - area.height * value / maxValue;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 2;
    final step = maxValue > 10 ? 4 : (maxValue > 6 ? 2 : 1);
    for (var value = 0; value <= maxValue; value += step) {
      final y = area.bottom - area.height * value / maxValue;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
      _text(canvas, '$value', Offset(area.left - 6, y), alignRight: true);
    }
    canvas
      ..drawLine(area.bottomLeft, area.bottomRight, axis)
      ..drawLine(area.topLeft, area.bottomLeft, axis);

    final targetY = area.bottom - area.height * target / maxValue;
    final dashed = Paint()
      ..color = targetColor
      ..strokeWidth = 2;
    for (var x = area.left; x < area.right; x += 12) {
      canvas.drawLine(
        Offset(x, targetY),
        Offset(math.min(x + 6, area.right), targetY),
        dashed,
      );
    }
    _text(
      canvas,
      targetLabel,
      Offset(area.right, targetY - 4),
      alignRight: true,
      alignBottom: true,
    );

    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    if (points.length > 1) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final p = position(area, i, points[i].value);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, line);
    }
    for (var i = 0; i < points.length; i++) {
      final p = position(area, i, points[i].value);
      if (points[i].reached) {
        canvas.drawCircle(p, _marker, Paint()..color = lineColor);
      } else {
        canvas
          ..drawCircle(p, _marker, Paint()..color = fillColor)
          ..drawCircle(p, _marker, line);
      }
      _text(canvas, '${i + 1}', Offset(p.dx, area.bottom + 6), center: true);
    }
    _text(
      canvas,
      axisLabelX,
      Offset((area.left + area.right) / 2, size.height - 2),
      center: true,
      alignBottom: true,
    );
    _text(canvas, axisLabelY, Offset.zero);
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool alignRight = false,
    bool center = false,
    bool alignBottom = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
    var dx = anchor.dx;
    var dy = anchor.dy;
    if (alignRight) dx -= painter.width;
    if (center) dx -= painter.width / 2;
    if (alignBottom) {
      dy -= painter.height;
    } else if (alignRight) {
      dy -= painter.height / 2;
    }
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(ProgressChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.target != target ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.targetColor != targetColor ||
      oldDelegate.axisLabelX != axisLabelX ||
      oldDelegate.axisLabelY != axisLabelY ||
      oldDelegate.targetLabel != targetLabel;
}
