import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/billiard_cue.dart';
import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/table_diagram/diagram_timeline.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

/// Schéma d'exercice : table, billes, cercles creux, flèches et zones.
///
/// Sans [frame], le schéma montre l'état initial de [spec] (avec la queue
/// pointée sur la cible si un tir est décrit). Avec une [frame] issue de
/// `DiagramTimeline`, il montre les billes à cet instant ; les billes
/// empochées ne sont plus dessinées.
///
/// [semanticLabel] décrit l'exercice (texte localisé fourni par l'appelant).
/// Sur une table réduite, la bille est trop petite pour porter sa lettre : la
/// lettre (R/J/N/B) est alors écrite à côté, avec le repère éventuel (« x4 »).
/// Les flèches se distinguent par leur trait (plein : bille touchée ; tirets :
/// blanche ; points : indication), pas par la couleur.
class TableDiagram extends StatelessWidget {
  const TableDiagram({
    required this.spec,
    required this.semanticLabel,
    this.frame,
    this.showGrid = true,
    this.showHeadString = true,
    super.key,
  });

  final TableDiagramSpec spec;

  /// Description de l'exercice pour les lecteurs d'écran.
  final String semanticLabel;

  /// État à afficher ; l'état initial de [spec] si absent.
  final DiagramFrame? frame;

  final bool showGrid;
  final bool showHeadString;

  /// Diamètre (px) à partir duquel la lettre tient dans la bille.
  static const double _letterInside = 28;

  @override
  Widget build(BuildContext context) {
    final DiagramFrame current;
    try {
      current = frame ?? DiagramTimeline.of(spec).initialFrame;
    } on InvalidDiagramException {
      return ErrorView(message: AppLocalizations.of(context).diagramInvalid);
    }
    return Semantics(
      label: semanticLabel,
      container: true,
      child: BilliardTable(
        showGrid: showGrid,
        showHeadString: showHeadString,
        overlay: (context, geometry) => _overlay(context, geometry, current),
      ),
    );
  }

  Widget _overlay(
    BuildContext context,
    TableGeometry geometry,
    DiagramFrame current,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final table = theme.extension<TableColors>() ?? TableColors.light;
    // Repère de taille des étiquettes : une bille de but (la blanche est un
    // peu plus petite, voir `BallKind.radius`).
    final diameter = geometry.radiusPxOf(BallKind.red) * 2;
    final textStyle = theme.textTheme.labelSmall?.copyWith(
      color: balls.onCloth,
    );

    final cueId = current.cueAngle != null && current.stepIndex >= 0
        ? spec.steps[current.stepIndex].cueId
        : null;
    final cuePosition = cueId == null ? null : current.balls[cueId]?.position;
    final cueKind = cueId == null ? BallKind.white : _colorOf(cueId);

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GuidePainter(
                spec: spec,
                geometry: geometry,
                ink: table.headString,
              ),
            ),
          ),
          for (final ghost in spec.ghosts)
            if (ghost.label != null)
              Positioned(
                left: geometry.toPixel(_offset(ghost.at)).dx + diameter * 0.6,
                top: geometry.toPixel(_offset(ghost.at)).dy - diameter * 1.6,
                child: Text(ghost.label!, softWrap: false, style: textStyle),
              ),
          for (final note in spec.annotations)
            Positioned(
              key: ValueKey('annotation-${note.id}'),
              left: geometry.toPixel(_offset(note.at)).dx + diameter * 0.8,
              top: geometry.toPixel(_offset(note.at)).dy - diameter * 2.2,
              child: Text(note.text, softWrap: false, style: textStyle),
            ),
          if (cuePosition != null)
            BilliardCue.positionedAgainst(
              geometry: geometry,
              ball: _offset(cuePosition),
              angle: current.cueAngle!,
              touching: cueKind,
            ),
          for (final ball in spec.balls)
            if (!(current.balls[ball.id]?.pocketed ?? false))
              Positioned.fromRect(
                key: ValueKey('ball-${ball.id}'),
                rect: geometry.ballRect(
                  _offset(current.balls[ball.id]?.position ?? ball.at),
                  _kind(ball.color),
                ),
                child: BilliardBall(
                  kind: _kind(ball.color),
                  diameter: geometry.radiusPxOf(_kind(ball.color)) * 2,
                  label: _label(
                    l10n,
                    ball,
                    geometry.radiusPxOf(_kind(ball.color)) * 2,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  /// Couleur de la bille [id] du schéma (la blanche à défaut).
  BallKind _colorOf(String id) {
    for (final ball in spec.balls) {
      if (ball.id == id) return _kind(ball.color);
    }
    return BallKind.white;
  }

  static String? _label(
    AppLocalizations l10n,
    DiagramBall ball,
    double diameter,
  ) {
    if (diameter >= _letterInside) return ball.label;
    final letter = ballKindLetter(l10n, _kind(ball.color));
    return ball.label == null ? letter : '$letter ${ball.label}';
  }
}

Offset _offset(DiagramPoint p) => Offset(p.x, p.y);

BallKind _kind(BallKind color) => switch (color) {
  BallKind.red => BallKind.red,
  BallKind.yellow => BallKind.yellow,
  BallKind.black => BallKind.black,
  BallKind.white => BallKind.white,
};

/// Peint ce qui est sous les billes : zones, flèches, repères de rebond et
/// cercles creux. Une seule teinte (`TableColors.headString`, contraste 3:1
/// testé sur le tapis) ; la nature se lit au trait.
class _GuidePainter extends CustomPainter {
  const _GuidePainter({
    required this.spec,
    required this.geometry,
    required this.ink,
  });

  final TableDiagramSpec spec;
  final TableGeometry geometry;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final u = geometry.unit;
    if (u <= 0) return;
    final width = math.max(1.5, u * 0.045);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final zone in spec.zones) {
      final rect = Rect.fromPoints(
        geometry.toPixel(_offset(zone.from)),
        geometry.toPixel(_offset(zone.to)),
      );
      canvas
        ..drawRect(rect, Paint()..color = ink.withValues(alpha: 0.18))
        ..drawRect(rect, line..strokeWidth = 1);
      line.strokeWidth = width;
    }

    for (final ghost in spec.ghosts) {
      if (ghost.role == DiagramGhostRole.contact) {
        // Point de contact : petit disque plein (rayon du procédé, 8,5 mm).
        canvas.drawCircle(
          geometry.toPixel(_offset(ghost.at)),
          math.max(
            2.5,
            BlackballDimensions.tipDiameterMm /
                2 /
                BlackballDimensions.cellMm *
                u,
          ),
          Paint()..color = ink,
        );
        continue;
      }
      final circle = Path()
        ..addOval(
          Rect.fromCircle(
            center: geometry.toPixel(_offset(ghost.at)),
            radius: geometry.ghostRadiusPx,
          ),
        );
      _drawDashed(canvas, circle, line, dash: u * 0.06, gap: u * 0.05);
    }

    for (final arrow in spec.arrows) {
      if (arrow.path.length < 2) continue;
      final points = [for (final p in arrow.path) geometry.toPixel(_offset(p))];
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      switch (arrow.kind) {
        case DiagramArrowKind.object:
          canvas.drawPath(path, line);
        case DiagramArrowKind.cue:
          _drawDashed(canvas, path, line, dash: u * 0.18, gap: u * 0.12);
        case DiagramArrowKind.aim:
          _drawPattern(canvas, path, line, [
            u * 0.3,
            u * 0.07,
            u * 0.03,
            u * 0.07,
          ]);
        case DiagramArrowKind.indication:
          _drawDashed(
            canvas,
            path,
            line..strokeWidth = width * 0.75,
            dash: u * 0.03,
            gap: u * 0.1,
          );
          line.strokeWidth = width;
      }
      _drawHead(canvas, points, u, line);
      for (final bounce in arrow.bouncePoints) {
        canvas.drawCircle(geometry.toPixel(_offset(bounce)), width * 1.6, line);
      }
    }
  }

  void _drawHead(Canvas canvas, List<Offset> points, double u, Paint line) {
    final tip = points.last;
    var from = points.length - 2;
    while (from > 0 && (tip - points[from]).distance == 0) {
      from--;
    }
    final back = points[from];
    final length = (tip - back).distance;
    if (length == 0) return;
    final direction = (tip - back) / length;
    final side = Offset(-direction.dy, direction.dx);
    final size = math.min(u * 0.22, length);
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - direction.dx * size + side.dx * size * 0.45,
        tip.dy - direction.dy * size + side.dy * size * 0.45,
      )
      ..lineTo(
        tip.dx - direction.dx * size - side.dx * size * 0.45,
        tip.dy - direction.dy * size - side.dy * size * 0.45,
      )
      ..close();
    canvas.drawPath(head, Paint()..color = line.color);
  }

  /// Trait-point : [pattern] alterne longueurs tracées et blancs.
  void _drawPattern(
    Canvas canvas,
    Path path,
    Paint paint,
    List<double> pattern,
  ) {
    final steps = [for (final p in pattern) math.max(p, 0.5)];
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      var i = 0;
      while (d < metric.length) {
        final length = steps[i % steps.length];
        if (i.isEven) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + length, metric.length)),
            paint,
          );
        }
        d += length;
        i++;
      }
    }
  }

  void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final step = math.max(dash, 0.5);
    final space = math.max(gap, 0.5);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += step + space) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + step, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.spec != spec ||
      old.geometry.surface != geometry.surface ||
      old.ink != ink;
}
