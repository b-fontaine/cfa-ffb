import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/lib/cue_side_geometry.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/cue_side_view.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

export 'package:billard_cfa/shared/lib/illustration.dart' show CueHeight;
export 'package:billard_cfa/shared/ui/tip_point.dart';

/// Géométrie de la cible dessinée sur la blanche vue de face.
///
/// La blanche est dessinée à sa propre taille ([radius] en pixels). Le
/// procédé (8,5 mm) est dessiné à l'échelle de la blanche (48,0 mm) : son
/// rayon vaut `BlackballDimensions.tipRadiusOnCueBall` (0,177) rayon de
/// blanche, avec un plancher de [minMarkerRadius] pixels pour la projection.
/// Les positions sont des propositions `[Prop]` : mi-rayon du centre
/// (`tipOffsetShare`), comme le point bleu de la fiche n° 3.
class CueBallTargetGeometry {
  const CueBallTargetGeometry({required this.center, required this.radius});

  /// Centre de la blanche, en pixels.
  final Offset center;

  /// Rayon de la blanche, en pixels.
  final double radius;

  /// Rayon minimal du repère du procédé, en pixels (lisible en projection).
  static const double minMarkerRadius = 10;

  /// Rayons des deux anneaux de la cible : mi-rayon et bord de la blanche.
  List<double> get ringRadii => [radius * 0.5, radius];

  /// Centre du repère du procédé pour [tip].
  Offset markerCenter(TipPoint tip) =>
      center + tip.direction * (radius * tipOffsetShare);

  /// Rayon du repère du procédé, en pixels.
  double get markerRadius => math.max(
    minMarkerRadius,
    radius * BlackballDimensions.tipRadiusOnCueBall,
  );

  /// Vrai quand le plancher agrandit le repère : l'échelle n'est alors plus
  /// exacte et un anneau de visibilité est dessiné.
  bool get markerEnlarged =>
      radius * BlackballDimensions.tipRadiusOnCueBall < minMarkerRadius;
}

/// La blanche vue de face avec une cible et le point d'impact du procédé.
///
/// Deux anneaux (mi-rayon et bord), une croix dont les quatre branches sont
/// nommées, et le procédé dessiné **à l'échelle de la blanche**. Les points de
/// [compare] sont des cercles creux lettrés A, B, C. Avec [cueHeight], un
/// petit profil montre la hauteur de la queue.
///
/// La position du point d'impact n'est jamais portée par la seule couleur :
/// le texte en donne le nom et la description parlée le répète.
class CueBallTarget extends StatelessWidget {
  const CueBallTarget({
    required this.tipPoint,
    this.compare = const [],
    this.cueHeight,
    super.key,
  });

  /// Point d'impact du procédé.
  final TipPoint tipPoint;

  /// Points d'appui de comparaison, dessinés en cercles creux lettrés.
  final List<TipPoint> compare;

  /// Hauteur du talon de la queue ; absente, aucun profil n'est dessiné.
  final CueHeight? cueHeight;

  /// Côté maximal de la zone de dessin, en pixels.
  static const double _maxSide = 240;

  /// Côté minimal de la zone de dessin, en pixels.
  static const double _minSide = 64;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tip = BallContactDiagram.tipLabel(l10n, tipPoint);
    final height = cueHeight == null
        ? null
        : CueSideView.heightLabel(l10n, cueHeight!);
    final format = NumberFormat(
      '0.0',
      Localizations.localeOf(context).toString(),
    );
    final parts = [
      l10n.cueBallTargetLabel(tip),
      if (height != null) l10n.cueBallTargetProfile(height),
      if (compare.isNotEmpty)
        l10n.cueBallTargetCompareLabel(
          compare.map((p) => BallContactDiagram.tipLabel(l10n, p)).join(', '),
        ),
    ];
    final textStyle = theme.textTheme.bodyMedium;
    final scaler = MediaQuery.textScalerOf(context);
    // Largeur réservée à « Gauche » / « Droite » de chaque côté de la bille.
    final sideLabel = scaler.scale(14) * 3.6 + AppSpacing.sm;

    return Semantics(
      label: parts.join(' '),
      container: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Les noms des côtés cèdent de la place à la bille quand l'écran est
          // étroit : jamais de débordement du rang.
          final label = math.min(
            sideLabel,
            math.max<double>(
              0,
              (constraints.maxWidth - _minSide - 2 * AppSpacing.xs) / 2,
            ),
          );
          final side = math.max<double>(
            0,
            math.min(
              _maxSide,
              constraints.maxWidth - 2 * (label + AppSpacing.xs),
            ),
          );
          final radius = side / 2 - 4;
          final geometry = CueBallTargetGeometry(
            center: Offset(side / 2, side / 2),
            radius: radius,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.cueBallTargetAxisTop, style: textStyle),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: label,
                    child: Text(
                      l10n.cueBallTargetAxisLeft,
                      textAlign: TextAlign.end,
                      style: textStyle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: side,
                    height: side,
                    child: _Front(
                      geometry: geometry,
                      tipPoint: tipPoint,
                      compare: compare,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: label,
                    child: Text(l10n.cueBallTargetAxisRight, style: textStyle),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.cueBallTargetAxisBottom, style: textStyle),
              const SizedBox(height: AppSpacing.sm),
              Text(tip, textAlign: TextAlign.center, style: textStyle),
              if (!geometry.markerEnlarged)
                Text(
                  l10n.cueBallTargetScaleNote(
                    format.format(BlackballDimensions.tipDiameterMm),
                    format.format(BlackballDimensions.cueBallDiameterMm),
                  ),
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              if (cueHeight != null) ...[
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: AspectRatio(
                    key: const ValueKey('cue-ball-profile'),
                    aspectRatio: 2.4,
                    child: CustomPaint(
                      painter: _ProfilePainter(
                        tipPoint: tipPoint,
                        cueHeight: cueHeight!,
                        balls:
                            theme.extension<BallColors>() ?? BallColors.light,
                        table:
                            theme.extension<TableColors>() ?? TableColors.light,
                        surface: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(height!, textAlign: TextAlign.center, style: textStyle),
                Text(
                  l10n.cueNotToScale,
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Lettre d'un point de comparaison : A, B, C...
String _letter(int index) => String.fromCharCode(0x41 + index);

class _Front extends StatelessWidget {
  const _Front({
    required this.geometry,
    required this.tipPoint,
    required this.compare,
  });

  final CueBallTargetGeometry geometry;
  final TipPoint tipPoint;
  final List<TipPoint> compare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final table = theme.extension<TableColors>() ?? TableColors.light;
    final letterStyle = theme.textTheme.labelLarge?.copyWith(
      color: balls.onWhite,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _FrontPainter(
              geometry: geometry,
              tipPoint: tipPoint,
              compare: compare,
              balls: balls,
              table: table,
            ),
          ),
        ),
        for (final (i, point) in compare.indexed)
          Positioned(
            left: geometry.markerCenter(point).dx - 10,
            top: geometry.markerCenter(point).dy - 10,
            width: 20,
            height: 20,
            child: Center(child: Text(_letter(i), style: letterStyle)),
          ),
      ],
    );
  }
}

class _FrontPainter extends CustomPainter {
  const _FrontPainter({
    required this.geometry,
    required this.tipPoint,
    required this.compare,
    required this.balls,
    required this.table,
  });

  final CueBallTargetGeometry geometry;
  final TipPoint tipPoint;
  final List<TipPoint> compare;
  final BallColors balls;
  final TableColors table;

  static const double _stroke = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final c = geometry.center;
    final r = geometry.radius;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.height * 0.08),
      ),
      Paint()..color = balls.cloth,
    );
    paintBilliardBall(
      canvas,
      center: c,
      radius: r,
      fill: balls.white,
      balls: balls,
      table: table,
    );

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = balls.onWhite.withValues(alpha: 0.6);
    canvas
      ..drawCircle(c, geometry.ringRadii.first, line)
      ..drawCircle(c, geometry.ringRadii.last, line..color = balls.onWhite)
      ..drawLine(c.translate(-r * 1.1, 0), c.translate(r * 1.1, 0), line)
      ..drawLine(c.translate(0, -r * 1.1), c.translate(0, r * 1.1), line);

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = balls.onWhite;
    for (final point in compare) {
      canvas.drawCircle(
        geometry.markerCenter(point),
        geometry.markerRadius,
        outline,
      );
    }

    final tip = geometry.markerCenter(tipPoint);
    canvas
      ..drawCircle(tip, geometry.markerRadius, Paint()..color = table.chalk)
      ..drawCircle(tip, geometry.markerRadius, outline);
    if (geometry.markerEnlarged) {
      // Anneau pointillé : le repère est agrandi, l'échelle n'est plus exacte.
      final ring = geometry.markerRadius * 1.7;
      const dashes = 12;
      for (var i = 0; i < dashes; i++) {
        final start = 2 * math.pi * i / dashes;
        canvas.drawArc(
          Rect.fromCircle(center: tip, radius: ring),
          start,
          math.pi / dashes,
          false,
          outline,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FrontPainter old) =>
      old.geometry.center != geometry.center ||
      old.geometry.radius != geometry.radius ||
      old.tipPoint != tipPoint ||
      old.compare != compare ||
      old.balls != balls ||
      old.table != table;
}

/// Profil : la blanche posée sur le tapis, la queue et le procédé à la
/// hauteur du point d'impact. Un impact à gauche ou à droite ne se voit pas de
/// côté : il est dessiné à hauteur du centre.
class _ProfilePainter extends CustomPainter {
  const _ProfilePainter({
    required this.tipPoint,
    required this.cueHeight,
    required this.balls,
    required this.table,
    required this.surface,
  });

  final TipPoint tipPoint;
  final CueHeight cueHeight;
  final BallColors balls;
  final TableColors table;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.clipRect(Offset.zero & size);
    final clothTop = h * 0.82;
    final r = h * 0.3;
    final center = Offset(w * 0.68, clothTop - r);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(h * 0.06)),
        Paint()..color = surface,
      )
      ..drawRect(
        Rect.fromLTRB(0, clothTop, w, h),
        Paint()..color = balls.cloth,
      );
    paintBilliardBall(
      canvas,
      center: center,
      radius: r,
      fill: balls.white,
      balls: balls,
      table: table,
    );

    final dy = -tipHeightFactor(tipPoint) * r * tipOffsetShare;
    final tip = Offset(center.dx - math.sqrt(r * r - dy * dy), center.dy + dy);
    final elevation = cueElevation(cueHeight);
    final back = tip - Offset(math.cos(elevation), math.sin(elevation)) * w;
    final thickness = math.max<double>(6, r * 0.3);
    canvas
      ..drawLine(
        back,
        tip,
        Paint()
          ..strokeWidth = thickness + 3
          ..strokeCap = StrokeCap.round
          ..color = table.cueButt,
      )
      ..drawLine(
        back,
        tip,
        Paint()
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round
          ..color = table.cueWood,
      )
      ..drawCircle(tip, thickness / 2, Paint()..color = table.cueTip);
  }

  @override
  bool shouldRepaint(_ProfilePainter old) =>
      old.tipPoint != tipPoint ||
      old.cueHeight != cueHeight ||
      old.balls != balls ||
      old.table != table ||
      old.surface != surface;
}
