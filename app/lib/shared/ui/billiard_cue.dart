import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

/// Queue de billard peinte : procédé, virole, fût, talon.
///
/// Le widget occupe une boîte [length] × [thickness] avec la **pointe au
/// milieu du bord droit**. [angle] (radians, sens horaire, 0 = pointe vers la
/// droite) fait pivoter la queue **autour de la pointe** : la boîte, donc la
/// position de la pointe, ne bouge pas. Posée sur une table, utiliser
/// [BilliardCue.positionedAgainst] : la queue y a les proportions du matériel
/// (1450 mm de long, talon de 30 mm, procédé de 8,5 mm) par rapport aux billes
/// et à la table.
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

  /// Longueur maximale (px) d'une queue de pointe [tip], d'épaisseur de talon
  /// [thickness] et de direction [angle], pour que ses deux coins de talon
  /// restent dans [bounds] : au-delà, le rail ou le bord du widget la
  /// couperait. Vaut au plus [length] et au moins 0.
  static double lengthWithin({
    required Rect bounds,
    required Offset tip,
    required double length,
    required double thickness,
    required double angle,
  }) {
    final direction = Offset(math.cos(angle), math.sin(angle));
    final side = Offset(-direction.dy, direction.dx);
    var fit = length;
    for (final sign in [1.0, -1.0]) {
      // Coin du talon à la distance L : corner = from - direction * L.
      final from = tip + side * (sign * thickness / 2);
      fit = math.min(
        fit,
        math.min(
          _reach(from.dx, direction.dx, bounds.left, bounds.right),
          _reach(from.dy, direction.dy, bounds.top, bounds.bottom),
        ),
      );
    }
    return math.max(0, fit);
  }

  /// Distance max L telle que `from - step * L` reste dans [low, high].
  static double _reach(double from, double step, double low, double high) {
    if (step.abs() < 1e-9) return double.infinity;
    final toLow = (from - low) / step;
    final toHigh = (from - high) / step;
    return math.max(toLow, toHigh);
  }

  /// Queue posée dans la pile d'un `BilliardTable.overlay`, la pointe contre
  /// la bille en [ball] (repère de la table, de couleur [touching] : la blanche
  /// est plus petite qu'une bille de but), visant dans la direction [angle].
  ///
  /// Le talon ne sort jamais de la table (rails compris) : la queue est
  /// raccourcie de ce qu'il faut quand la blanche est près d'une bande.
  static Positioned positionedAgainst({
    required TableGeometry geometry,
    required Offset ball,
    double angle = 0,
    double lengthCells = BlackballDimensions.cueLength,
    BallKind touching = BallKind.white,
    Key? key,
  }) {
    final layout = layoutAgainst(
      geometry: geometry,
      ball: ball,
      angle: angle,
      lengthCells: lengthCells,
      touching: touching,
    );
    return Positioned(
      key: key,
      left: layout.tip.dx - layout.length,
      top: layout.tip.dy - layout.thickness / 2,
      width: layout.length,
      height: layout.thickness,
      child: BilliardCue(
        length: layout.length,
        thickness: layout.thickness,
        angle: angle,
      ),
    );
  }

  /// Pointe (px), longueur et épaisseur retenues pour une queue posée contre la
  /// bille en [ball] : ce que [positionedAgainst] dessine, pour que d'autres
  /// calculs (placement des étiquettes) voient la même queue.
  static ({Offset tip, double length, double thickness}) layoutAgainst({
    required TableGeometry geometry,
    required Offset ball,
    double angle = 0,
    double lengthCells = BlackballDimensions.cueLength,
    BallKind touching = BallKind.white,
  }) {
    final thickness = math.max<double>(
      7,
      geometry.unit * BlackballDimensions.cueButtThickness,
    );
    final direction = Offset(math.cos(angle), math.sin(angle));
    final tip =
        geometry.toPixel(ball) - direction * geometry.radiusPxOf(touching);
    final length = lengthWithin(
      bounds: geometry.tableRect,
      tip: tip,
      length: lengthCells * geometry.unit,
      thickness: thickness,
      angle: angle,
    );
    return (tip: tip, length: length, thickness: thickness);
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

  /// Épaisseur relative à la distance [s] (0..1) depuis la pointe : de la
  /// finesse du procédé (8,5 mm sur un talon de 30 mm) à l'épaisseur du talon.
  static double _width(double s) {
    const tip = BlackballDimensions.cueTipToButt;
    return s <= 0.6
        ? tip + (0.7 - tip) * (s / 0.6)
        : 0.7 + (1 - 0.7) * ((s - 0.6) / 0.4);
  }

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
