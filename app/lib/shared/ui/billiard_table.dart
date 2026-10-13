import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

/// Construit ce qui se pose sur la table (billes, flèches, queue).
typedef TableOverlayBuilder = Widget Function(
  BuildContext context,
  TableGeometry geometry,
);

/// Table de Blackball vue de dessus, en paysage (surface 2:1).
///
/// Tapis, bandes, rails gris bois avec losanges, six poches ; en option la
/// grille pointillée 8 × 4 ([showGrid]) et la ligne de départ à x = 2
/// ([showHeadString]). Les poches ont l'ouverture réelle (76,2 mm, 1,5 bille
/// de but). [overlay] reçoit la [TableGeometry] pour placer billes, flèches et
/// queue dans le repère de la table (blanche plus petite que les billes de
/// but). Le widget a le rapport (8 + 1) : (4 + 1) : la surface 2:1 plus un rail
/// d'une demi-case autour.
class BilliardTable extends StatelessWidget {
  const BilliardTable({
    this.showGrid = false,
    this.showHeadString = false,
    this.overlay,
    super.key,
  });

  final bool showGrid;
  final bool showHeadString;
  final TableOverlayBuilder? overlay;

  static const double _aspect =
      (TableGeometry.columns + 2 * TableGeometry.railWidth) /
      (TableGeometry.rows + 2 * TableGeometry.railWidth);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final table = theme.extension<TableColors>() ?? TableColors.light;
    final label = AppLocalizations.of(context).billiardTableLabel;
    return Semantics(
      label: label,
      container: true,
      child: AspectRatio(
        aspectRatio: _aspect,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final geometry = TableGeometry.fitting(constraints.biggest);
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TablePainter(
                      balls: balls,
                      table: table,
                      showGrid: showGrid,
                      showHeadString: showHeadString,
                    ),
                  ),
                ),
                if (overlay != null)
                  Positioned.fill(child: overlay!(context, geometry)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
  const _TablePainter({
    required this.balls,
    required this.table,
    required this.showGrid,
    required this.showHeadString,
  });

  final BallColors balls;
  final TableColors table;
  final bool showGrid;
  final bool showHeadString;

  static const double _cushion = 0.18;

  /// Demi-diagonale d'un losange en cases : repère de lecture, agrandi par
  /// rapport aux cibles réelles (≈ 12 mm) pour rester visible en projection.
  static const double _diamond = 0.07;

  @override
  void paint(Canvas canvas, Size size) {
    final g = TableGeometry.fitting(size);
    final u = g.unit;
    if (u <= 0) return;

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(g.tableRect, Radius.circular(0.3 * u)),
        Paint()..color = table.rail,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          g.surface.inflate(_cushion * u),
          Radius.circular(0.08 * u),
        ),
        Paint()..color = table.cushion,
      )
      ..drawRect(g.surface, Paint()..color = balls.cloth);

    if (showGrid) _paintGrid(canvas, g);
    if (showHeadString) {
      canvas.drawLine(
        g.toPixel(const Offset(TableGeometry.headStringX, 0)),
        g.toPixel(const Offset(TableGeometry.headStringX, TableGeometry.rows)),
        Paint()
          ..color = table.headString
          ..strokeWidth = u * 0.04 < 1.5 ? 1.5 : u * 0.04,
      );
    }

    _paintDiamonds(canvas, g);
    for (final pocket in TablePocket.values) {
      canvas.drawCircle(
        g.pocketCenter(pocket),
        g.pocketRadiusPx,
        Paint()..color = table.pocket,
      );
    }
  }

  void _paintGrid(Canvas canvas, TableGeometry g) {
    final paint = Paint()
      ..color = table.grid.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    final dash = g.unit * 0.06;
    for (var x = 1; x < TableGeometry.columns; x++) {
      _dashed(
        canvas,
        g.toPixel(Offset(x.toDouble(), 0)),
        g.toPixel(Offset(x.toDouble(), TableGeometry.rows)),
        dash,
        paint,
      );
    }
    for (var y = 1; y < TableGeometry.rows; y++) {
      _dashed(
        canvas,
        g.toPixel(Offset(0, y.toDouble())),
        g.toPixel(Offset(TableGeometry.columns, y.toDouble())),
        dash,
        paint,
      );
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, double dash, Paint paint) {
    final length = (b - a).distance;
    if (dash <= 0 || length <= 0) return;
    final direction = (b - a) / length;
    for (var d = 0.0; d < length; d += dash * 2) {
      final end = d + dash < length ? d + dash : length;
      canvas.drawLine(a + direction * d, a + direction * end, paint);
    }
  }

  void _paintDiamonds(Canvas canvas, TableGeometry g) {
    final centers = <Offset>[
      for (final x in const [1.0, 2.0, 3.0, 5.0, 6.0, 7.0]) ...[
        Offset(x, -0.34),
        Offset(x, TableGeometry.rows + 0.34),
      ],
      for (final y in const [1.0, 2.0, 3.0]) ...[
        Offset(-0.34, y),
        Offset(TableGeometry.columns + 0.34, y),
      ],
    ];
    final paint = Paint()..color = table.diamond;
    final h = _diamond * g.unit;
    for (final c in centers) {
      final p = g.toPixel(c);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - h)
          ..lineTo(p.dx + h, p.dy)
          ..lineTo(p.dx, p.dy + h)
          ..lineTo(p.dx - h, p.dy)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TablePainter old) =>
      old.balls != balls ||
      old.table != table ||
      old.showGrid != showGrid ||
      old.showHeadString != showHeadString;
}
