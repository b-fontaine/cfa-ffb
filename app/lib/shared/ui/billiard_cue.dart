import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

/// Queue de billard peinte : procédé, virole, fût, talon.
///
/// Le widget occupe une boîte [length] × [thickness] avec la **pointe au
/// milieu du bord droit**. [angle] (radians, sens horaire, 0 = pointe vers la
/// droite) fait pivoter la queue **autour de la pointe** : la boîte, donc la
/// position de la pointe, ne bouge pas. Posée sur une table, utiliser
/// [BilliardCue.positionedAgainst].
class BilliardCue extends StatelessWidget {
  const BilliardCue({
    this.length = 200,
    this.thickness = 10,
    this.angle = 0,
    super.key,
  });

  /// Longueur en pixels.
  final double length;

  /// Épaisseur du talon en pixels.
  final double thickness;

  /// Direction de la pointe, en radians (0 = vers la droite, π/2 = vers le bas).
  final double angle;

  /// Queue posée dans la pile d'un `BilliardTable.overlay`, la pointe contre
  /// la bille en [ball] (repère de la table), visant dans la direction [angle].
  static Positioned positionedAgainst({
    required TableGeometry geometry,
    required Offset ball,
    double angle = 0,
    double lengthCells = 5,
    Key? key,
  }) {
    final length = lengthCells * geometry.unit;
    final thickness = math.max<double>(7, geometry.unit * 0.2);
    final direction = Offset(math.cos(angle), math.sin(angle));
    final tip = geometry.toPixel(ball) - direction * geometry.ballRadiusPx;
    return Positioned(
      key: key,
      left: tip.dx - length,
      top: tip.dy - thickness / 2,
      width: length,
      height: thickness,
      child: BilliardCue(length: length, thickness: thickness, angle: angle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final table =
        Theme.of(context).extension<TableColors>() ?? TableColors.light;
    return Semantics(
      label: AppLocalizations.of(context).billiardCueLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: length,
        height: thickness,
        child: Transform.rotate(
          angle: angle,
          alignment: Alignment.centerRight,
          child: CustomPaint(
            size: Size(length, thickness),
            painter: _CuePainter(table: table),
          ),
        ),
      ),
    );
  }
}

class _CuePainter extends CustomPainter {
  const _CuePainter({required this.table});

  final TableColors table;

  /// Épaisseur relative à la distance [s] (0..1) depuis la pointe.
  static double _width(double s) => s <= 0.6
      ? 0.45 + (0.7 - 0.45) * (s / 0.6)
      : 0.7 + (1 - 0.7) * ((s - 0.6) / 0.4);

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    Path part(double s0, double s1) {
      final x0 = size.width * (1 - s0);
      final x1 = size.width * (1 - s1);
      final h0 = size.height * _width(s0) / 2;
      final h1 = size.height * _width(s1) / 2;
      return Path()
        ..moveTo(x0, cy - h0)
        ..lineTo(x1, cy - h1)
        ..lineTo(x1, cy + h1)
        ..lineTo(x0, cy + h0)
        ..close();
    }

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round
      ..color = table.cueButt;
    final segments = <(double, double, Color)>[
      (0, 0.015, table.cueTip),
      (0.015, 0.045, table.cueFerrule),
      (0.045, 0.6, table.cueWood),
      (0.6, 1, table.cueButt),
    ];
    for (final (s0, s1, color) in segments) {
      final path = part(s0, s1);
      canvas
        ..drawPath(path, Paint()..color = color)
        ..drawPath(path, outline);
    }
    // Anneau de jonction entre le fût et le talon.
    canvas.drawPath(part(0.59, 0.61), Paint()..color = table.cueFerrule);
  }

  @override
  bool shouldRepaint(_CuePainter old) => old.table != table;
}
