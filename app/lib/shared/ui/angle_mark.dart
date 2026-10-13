import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/angle_geometry.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

/// Marque d'angle sur la table : deux rayons issus d'un sommet, un arc entre
/// eux (un petit carré pour l'angle droit) et la valeur en degrés, **calculée**
/// depuis les rayons.
///
/// [vertex] et [rays] sont dans le repère de la table (cases). Avec moins de
/// deux rayons, il n'y a pas d'angle : seuls les rayons donnés sont tracés.
class AngleMark extends StatelessWidget {
  const AngleMark({
    required this.kind,
    required this.vertex,
    required this.rays,
    super.key,
  });

  final AngleKind kind;
  final math.Point<double> vertex;
  final List<math.Point<double>> rays;

  static String kindLabel(AppLocalizations l10n, AngleKind kind) =>
      switch (kind) {
        AngleKind.bounce => l10n.angleKindBounce,
        AngleKind.naturalRejection => l10n.angleKindNaturalRejection,
        AngleKind.rightAngle => l10n.angleKindRightAngle,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final table = theme.extension<TableColors>() ?? TableColors.light;
    final hasAngle = rays.length >= 2;
    final degrees = hasAngle
        ? angleDegrees(vertex: vertex, a: rays[0], b: rays[1])
        : null;
    final name = kindLabel(l10n, kind);
    return Semantics(
      label: degrees == null ? name : l10n.angleMarkLabel(name, degrees),
      container: true,
      excludeSemantics: true,
      child: BilliardTable(
        showGrid: true,
        overlay: (context, geometry) {
          final unit = geometry.unit;
          final origin = geometry.toPixel(Offset(vertex.x, vertex.y));
          Offset? labelAt;
          if (hasAngle) {
            final u = _unit(rays[0] - vertex);
            final v = _unit(rays[1] - vertex);
            var bisector = u + v;
            if (bisector.distance < 1e-9) bisector = Offset(-u.dy, u.dx);
            labelAt = origin + bisector / bisector.distance * (unit * 1.1);
          }
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _AnglePainter(
                    geometry: geometry,
                    vertex: vertex,
                    rays: rays,
                    kind: kind,
                    ink: table.headString,
                  ),
                ),
              ),
              if (degrees != null && labelAt != null)
                Positioned(
                  left: labelAt.dx,
                  top: labelAt.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: Text(
                      '$degrees°',
                      softWrap: false,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: balls.onCloth,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static Offset _unit(math.Point<double> v) {
    final length = v.magnitude;
    return length == 0 ? Offset.zero : Offset(v.x / length, v.y / length);
  }
}

class _AnglePainter extends CustomPainter {
  const _AnglePainter({
    required this.geometry,
    required this.vertex,
    required this.rays,
    required this.kind,
    required this.ink,
  });

  final TableGeometry geometry;
  final math.Point<double> vertex;
  final List<math.Point<double>> rays;
  final AngleKind kind;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = geometry.unit;
    if (unit <= 0) return;
    final origin = geometry.toPixel(Offset(vertex.x, vertex.y));
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, unit * 0.06)
      ..strokeCap = StrokeCap.round;

    final ends = [
      for (final r in rays.take(2)) geometry.toPixel(Offset(r.x, r.y)),
    ];
    for (final end in ends) {
      canvas.drawLine(origin, end, line);
    }
    canvas.drawCircle(origin, line.strokeWidth * 1.4, Paint()..color = ink);
    if (ends.length < 2) return;

    final u = ends[0] - origin;
    final v = ends[1] - origin;
    if (u.distance == 0 || v.distance == 0) return;
    if (kind == AngleKind.rightAngle) {
      final a = u / u.distance * (unit * 0.4);
      final b = v / v.distance * (unit * 0.4);
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx + a.dx, origin.dy + a.dy)
          ..lineTo(origin.dx + a.dx + b.dx, origin.dy + a.dy + b.dy)
          ..lineTo(origin.dx + b.dx, origin.dy + b.dy),
        line,
      );
    } else {
      final start = math.atan2(u.dy, u.dx);
      final sweep = math.atan2(
        u.dx * v.dy - u.dy * v.dx,
        u.dx * v.dx + u.dy * v.dy,
      );
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: unit * 0.55),
        start,
        sweep,
        false,
        line,
      );
    }
  }

  @override
  bool shouldRepaint(_AnglePainter old) =>
      old.geometry.surface != geometry.surface ||
      old.vertex != vertex ||
      old.rays != rays ||
      old.kind != kind ||
      old.ink != ink;
}
