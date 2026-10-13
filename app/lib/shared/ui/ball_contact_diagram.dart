import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/ball_chip.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

export 'package:billard_cfa/shared/ui/contact_fraction.dart';

/// Point d'impact du procédé sur la blanche (vue de face).
enum TipPoint {
  center(Offset.zero),
  top(Offset(0, -1)),
  bottom(Offset(0, 1)),
  left(Offset(-1, 0)),
  right(Offset(1, 0));

  TipPoint(this.direction);

  /// Direction du point par rapport au centre (unité = rayon, 0 au centre).
  final Offset direction;
}

/// Petit schéma de la quantité de bille, comme en bas à droite des fiches.
///
/// À gauche, la blanche au contact de la bille cible vue de dessus avec le
/// recouvrement correct ; à droite, la blanche de face avec le point bleu du
/// procédé. Le libellé localisé de la quantité est écrit sous le schéma.
class BallContactDiagram extends StatelessWidget {
  const BallContactDiagram({
    required this.contact,
    this.tipPoint = TipPoint.center,
    this.target = BallKind.red,
    super.key,
  });

  final ContactFraction contact;
  final TipPoint tipPoint;

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
            aspectRatio: 2,
            child: CustomPaint(
              painter: _ContactPainter(
                contact: contact,
                tipPoint: tipPoint,
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
    required this.targetFill,
    required this.balls,
    required this.table,
  });

  final ContactFraction contact;
  final TipPoint tipPoint;
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

    // Vue de dessus : la blanche arrive de la gauche et touche la cible.
    final r = h * 0.2;
    final cy = h * 0.64;
    final cue = Offset(h * 0.45, cy);
    final offset = contact.centerOffset * r;
    final dx = math.sqrt(math.max(0, 4 * r * r - offset * offset));
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
      radius: r,
      fill: balls.white,
      balls: balls,
      table: table,
    );

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
    canvas.drawCircle(
      front + tipPoint.direction * (radius * 0.55),
      radius * 0.17,
      Paint()..color = table.chalk,
    );
  }

  @override
  bool shouldRepaint(_ContactPainter old) =>
      old.contact != contact ||
      old.tipPoint != tipPoint ||
      old.targetFill != targetFill ||
      old.balls != balls ||
      old.table != table;
}
