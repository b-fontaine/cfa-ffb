import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/cue_side_geometry.dart';
import 'package:billard_cfa/shared/ui/ball_chip.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:billard_cfa/shared/ui/tip_point.dart';
import 'package:flutter/material.dart';

export 'package:billard_cfa/shared/ui/tip_point.dart';

/// Petit schéma de la quantité de bille, comme en bas à droite des fiches.
///
/// À gauche, la blanche au contact de la bille cible vue de dessus avec le
/// recouvrement correct, **aux tailles réelles** : la blanche (48,0 mm) est
/// plus petite que la bille de but (50,8 mm), rapport 0,945, et leurs centres
/// sont à `r_c + r_o`. À droite (si [showTip]), la blanche de face avec le
/// point bleu du procédé (8,5 mm, à l'échelle de la blanche ; la vue de face
/// est un agrandissement). Le libellé localisé de la quantité est écrit sous
/// le schéma. Avec [showPaths], les trajectoires après le contact sont
/// dessinées : la bille de couleur dans la ligne des centres (déviation `θ`
/// par rapport à la ligne de visée) et la blanche, jouée sans rotation, sur
/// la tangente, à angle droit de la couleur (fiche n° 13) ; en bille pleine
/// la blanche s'arrête (carreau).
class BallContactDiagram extends StatelessWidget {
  const BallContactDiagram({
    required this.contact,
    this.tipPoint = TipPoint.center,
    this.tipOffset = TipOffset.half,
    this.target = BallKind.red,
    this.showTip = true,
    this.showPaths = false,
    super.key,
  });

  final ContactFraction contact;
  final TipPoint tipPoint;

  /// Écart du procédé au centre (« un peu au-dessus » : `slight`).
  final TipOffset tipOffset;

  /// Dessine les trajectoires des deux billes après le contact.
  final bool showPaths;

  /// Dessine la blanche de face avec le procédé (à droite) ; sans cela, seul
  /// le contact des deux billes est dessiné.
  final bool showTip;

  /// Rapport largeur / hauteur de la zone de dessin avec la vue de face.
  static const double aspectWithTip = 2;

  /// Rapport largeur / hauteur de la zone de dessin sans la vue de face.
  static const double aspectBallsOnly = 1.3;

  /// Groupe de la bille cible.
  final BallKind target;

  static String contactLabel(AppLocalizations l10n, ContactFraction c) =>
      switch (c) {
        ContactFraction.full => l10n.contactFull,
        ContactFraction.threeQuarter => l10n.contactThreeQuarter,
        ContactFraction.half => l10n.contactHalf,
        ContactFraction.quarter => l10n.contactQuarter,
        ContactFraction.thin => l10n.contactThin,
      };

  /// Angle de déviation (degrés entiers) de la bille de couleur et de la
  /// blanche jouée sans rotation : `θ` et `90 − θ` ; `null` en bille pleine
  /// (la blanche s'arrête).
  static ({int colour, int cue})? pathAngles(ContactFraction contact) {
    if (contact == ContactFraction.full) return null;
    final theta = (contact.nominalCutAngle() * 180 / math.pi).round();
    return (colour: theta, cue: 90 - theta);
  }

  static String tipLabel(
    AppLocalizations l10n,
    TipPoint p, [
    TipOffset offset = TipOffset.half,
  ]) => switch ((p, offset)) {
    (TipPoint.top, TipOffset.slight) => l10n.tipPointTopSlight,
    (TipPoint.bottom, TipOffset.slight) => l10n.tipPointBottomSlight,
    (TipPoint.left, TipOffset.slight) => l10n.tipPointLeftSlight,
    (TipPoint.right, TipOffset.slight) => l10n.tipPointRightSlight,
    (TipPoint.center, _) => l10n.tipPointCenter,
    (TipPoint.top, _) => l10n.tipPointTop,
    (TipPoint.bottom, _) => l10n.tipPointBottom,
    (TipPoint.left, _) => l10n.tipPointLeft,
    (TipPoint.right, _) => l10n.tipPointRight,
    (TipPoint.topLeft, _) => l10n.tipPointTopLeft,
    (TipPoint.topRight, _) => l10n.tipPointTopRight,
    (TipPoint.bottomLeft, _) => l10n.tipPointBottomLeft,
    (TipPoint.bottomRight, _) => l10n.tipPointBottomRight,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final table = theme.extension<TableColors>() ?? TableColors.light;
    final fraction = contactLabel(l10n, contact);
    final tip = tipLabel(l10n, tipPoint, tipOffset);
    final angles = pathAngles(contact);
    final paths = !showPaths
        ? null
        : angles == null
        ? l10n.contactPathsFullLabel
        : l10n.contactPathsLabel(angles.colour, angles.cue);
    return Semantics(
      label: paths == null
          ? l10n.contactDiagramLabel(fraction, tip)
          : l10n.contactDiagramPathsLabel(fraction, tip, paths),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: showTip ? aspectWithTip : aspectBallsOnly,
            child: CustomPaint(
              painter: _ContactPainter(
                contact: contact,
                tipPoint: tipPoint,
                offsetShare: tipOffsetShareOf(tipOffset),
                showTip: showTip,
                showPaths: showPaths,
                degrees: angles == null
                    ? null
                    : l10n.contactDegrees(angles.colour),
                textStyle: theme.textTheme.labelLarge,
                targetFill: balls.fillOf(target),
                balls: balls,
                table: table,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            fraction,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ContactPainter extends CustomPainter {
  const _ContactPainter({
    required this.contact,
    required this.tipPoint,
    required this.offsetShare,
    required this.showTip,
    required this.showPaths,
    required this.degrees,
    required this.textStyle,
    required this.targetFill,
    required this.balls,
    required this.table,
  });

  final ContactFraction contact;
  final TipPoint tipPoint;
  final double offsetShare;
  final bool showTip;
  final bool showPaths;

  /// Texte de l'angle de déviation (« ≈ 31° ») ; `null` en bille pleine.
  final String? degrees;
  final TextStyle? textStyle;
  final Color targetFill;
  final BallColors balls;
  final TableColors table;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(h * 0.08)),
      Paint()..color = balls.cloth,
    );

    // Vue de dessus : la blanche arrive de la gauche et touche la cible. `r`
    // est le rayon de la bille de but ; la blanche est plus petite (0,945) et
    // les centres sont à r_c + r_o, avec d = distance de la ligne de visée au
    // centre de la bille de but (docs/knowledge/02-techniques/
    // 06-dimensions-du-materiel.md § 3.3).
    final r = h * 0.2;
    final rc =
        r *
        BlackballDimensions.cueBallRadius /
        BlackballDimensions.objectBallRadius;
    final cy = h * 0.64;
    final cue = Offset(h * 0.45, cy);
    final offset =
        contact.aimOffset() / BlackballDimensions.objectBallRadius * r;
    final reach = r + rc;
    final dx = math.sqrt(math.max(0, reach * reach - offset * offset));
    final target = Offset(cue.dx + dx, cy - offset);

    final aim = Paint()
      ..color = table.headString.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    for (var x = h * 0.08; x < h * 1.1; x += h * 0.1) {
      canvas.drawLine(Offset(x, cy), Offset(x + h * 0.05, cy), aim);
    }
    paintBilliardBall(
      canvas,
      center: target,
      radius: r,
      fill: targetFill,
      balls: balls,
      table: table,
    );
    paintBilliardBall(
      canvas,
      center: cue,
      radius: rc,
      fill: balls.white,
      balls: balls,
      table: table,
    );
    if (showPaths) _paths(canvas, cue, target, r, rc);
    if (!showTip) return;

    // Vue de face de la blanche : repère en croix et point bleu du procédé.
    final front = Offset(h * 1.5, h * 0.5);
    final radius = h * 0.28;
    final cross = Paint()
      ..color = table.headString
      ..strokeWidth = 1.5;
    canvas
      ..drawLine(
        front.translate(-radius * 1.35, 0),
        front.translate(radius * 1.35, 0),
        cross,
      )
      ..drawLine(
        front.translate(0, -radius * 1.35),
        front.translate(0, radius * 1.35),
        cross,
      );
    paintBilliardBall(
      canvas,
      center: front,
      radius: radius,
      fill: balls.white,
      balls: balls,
      table: table,
    );
    // Cible : un anneau à mi-rayon, comme dans `CueBallTarget` ; puis le
    // procédé de 8,5 mm sur une blanche de 48,0 mm : 0,177 du rayon.
    canvas
      ..drawCircle(
        front,
        radius * 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = balls.onWhite.withValues(alpha: 0.6),
      )
      ..drawCircle(
        front + tipPoint.direction * (radius * offsetShare),
        radius * BlackballDimensions.tipRadiusOnCueBall,
        Paint()..color = table.chalk,
      );
  }

  /// Trajectoires après le contact : la couleur dans la ligne des centres,
  /// la blanche (sans rotation) sur la tangente ; arc de l'angle de déviation
  /// de la couleur par rapport à la ligne de visée, avec sa valeur.
  void _paths(Canvas canvas, Offset cue, Offset target, double r, double rc) {
    final ink = Paint()
      ..color = table.headString
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final centres = target - cue;
    final n = centres / centres.distance;
    // Bille de couleur : droit devant dans la ligne des centres.
    _arrow(canvas, target + n * r, target + n * (r * 2.6), ink);
    final angles = BallContactDiagram.pathAngles(contact);
    if (angles == null) {
      // Carreau : la blanche s'arrête ; un point sur place.
      canvas.drawCircle(cue, 3, Paint()..color = table.headString);
      return;
    }
    // Blanche : sur la tangente, vers l'avant (angle droit avec la couleur).
    final t = Offset(-n.dy, n.dx).dx >= 0
        ? Offset(-n.dy, n.dx)
        : Offset(n.dy, -n.dx);
    final dashed = Paint()
      ..color = table.headString
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final start = cue + t * rc;
    final end = cue + t * (rc * 2.4);
    final length = (end - start).distance;
    for (var d = 0.0; d < length; d += 10) {
      final a = start + t * d;
      final b = start + t * math.min(d + 5, length);
      canvas.drawLine(a, b, dashed);
    }
    _arrowHead(canvas, end, t, dashed);
    // Arc de la déviation de la couleur, entre la ligne de visée (horizontale)
    // et la ligne des centres, au centre de la bille de couleur.
    final theta = math.atan2(n.dy, n.dx);
    final arcRadius = r * 1.9;
    canvas.drawArc(
      Rect.fromCircle(center: target, radius: arcRadius),
      math.min(0, theta),
      theta.abs(),
      false,
      ink,
    );
    final text = degrees;
    if (text == null) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final at =
        target +
        Offset(arcRadius + 4, -painter.height / 2 + theta * arcRadius / 2);
    painter.paint(canvas, at);
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    canvas.drawLine(from, to, paint);
    final d = to - from;
    _arrowHead(canvas, to, d / d.distance, paint);
  }

  void _arrowHead(Canvas canvas, Offset tip, Offset dir, Paint paint) {
    const size = 7.0;
    final left = Offset(-dir.dy, dir.dx);
    canvas
      ..drawLine(tip, tip - dir * size + left * (size / 2), paint)
      ..drawLine(tip, tip - dir * size - left * (size / 2), paint);
  }

  @override
  bool shouldRepaint(_ContactPainter old) =>
      old.contact != contact ||
      old.tipPoint != tipPoint ||
      old.offsetShare != offsetShare ||
      old.showTip != showTip ||
      old.showPaths != showPaths ||
      old.degrees != degrees ||
      old.targetFill != targetFill ||
      old.balls != balls ||
      old.table != table;
}
