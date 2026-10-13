import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
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
/// le schéma.
class BallContactDiagram extends StatelessWidget {
  const BallContactDiagram({
    required this.contact,
    this.tipPoint = TipPoint.center,
    this.target = BallKind.red,
    this.showTip = true,
    super.key,
  });

  final ContactFraction contact;
  final TipPoint tipPoint;

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

  static String tipLabel(AppLocalizations l10n, TipPoint p) => switch (p) {
    TipPoint.center => l10n.tipPointCenter,
    TipPoint.top => l10n.tipPointTop,
    TipPoint.bottom => l10n.tipPointBottom,
    TipPoint.left => l10n.tipPointLeft,
    TipPoint.right => l10n.tipPointRight,
    TipPoint.topLeft => l10n.tipPointTopLeft,
    TipPoint.topRight => l10n.tipPointTopRight,
    TipPoint.bottomLeft => l10n.tipPointBottomLeft,
    TipPoint.bottomRight => l10n.tipPointBottomRight,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final table = theme.extension<TableColors>() ?? TableColors.light;
    final fraction = contactLabel(l10n, contact);
    return Semantics(
      label: l10n.contactDiagramLabel(fraction, tipLabel(l10n, tipPoint)),
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
                showTip: showTip,
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
    required this.showTip,
    required this.targetFill,
    required this.balls,
    required this.table,
  });

  final ContactFraction contact;
  final TipPoint tipPoint;
  final bool showTip;
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
        front + tipPoint.direction * (radius * 0.5),
        radius * BlackballDimensions.tipRadiusOnCueBall,
        Paint()..color = table.chalk,
      );
  }

  @override
  bool shouldRepaint(_ContactPainter old) =>
      old.contact != contact ||
      old.tipPoint != tipPoint ||
      old.showTip != showTip ||
      old.targetFill != targetFill ||
      old.balls != balls ||
      old.table != table;
}
