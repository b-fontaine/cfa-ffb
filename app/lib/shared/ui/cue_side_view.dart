import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/cue_side_geometry.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/player_figure_layout.dart';
import 'package:billard_cfa/shared/ui/ball_chip.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/billiard_cue.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

export 'package:billard_cfa/shared/lib/player_figure_layout.dart'
    show CueBridge;

/// Vue de côté de la blanche et de la queue : hauteur du talon, point
/// d'impact vertical du procédé et appui du chevalet.
///
/// Schéma non à l'échelle `[Prop]`. De côté, un impact à gauche ou à droite ne
/// se voit pas : il est dessiné à hauteur du centre ; le point exact est dit
/// dans la description parlée.
class CueSideView extends StatelessWidget {
  const CueSideView({
    required this.tipPoint,
    required this.cueHeight,
    this.bridge,
    super.key,
  });

  final TipPoint tipPoint;
  final CueHeight cueHeight;

  /// Appui du chevalet ; absent, aucune main n'est dessinée.
  final CueBridge? bridge;

  /// Rapport largeur / hauteur de la scène.
  static const double _aspect = 2.4;

  static String heightLabel(AppLocalizations l10n, CueHeight h) => switch (h) {
    CueHeight.low => l10n.cueHeightLow,
    CueHeight.level => l10n.cueHeightLevel,
    CueHeight.high => l10n.cueHeightHigh,
  };

  static String bridgeLabel(AppLocalizations l10n, CueBridge b) => switch (b) {
    CueBridge.frame => l10n.cueBridgeFrame,
    CueBridge.surface => l10n.cueBridgeSurface,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final height = heightLabel(l10n, cueHeight);
    final tip = BallContactDiagram.tipLabel(l10n, tipPoint);
    final bridgeName = bridge == null ? null : bridgeLabel(l10n, bridge!);
    final base = bridgeName == null
        ? l10n.cueSideLabel(height, tip)
        : l10n.cueSideLabelWithBridge(height, tip, bridgeName);
    return Semantics(
      label: base,
      container: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: _aspect,
            child: LayoutBuilder(
              builder: (context, constraints) => _Scene(
                size: constraints.biggest,
                tipPoint: tipPoint,
                cueHeight: cueHeight,
                bridge: bridge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            height,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (bridgeName != null)
            Text(
              bridgeName,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          Text(
            l10n.cueNotToScale,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Scene extends StatelessWidget {
  const _Scene({
    required this.size,
    required this.tipPoint,
    required this.cueHeight,
    required this.bridge,
  });

  final Size size;
  final TipPoint tipPoint;
  final CueHeight cueHeight;
  final CueBridge? bridge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final table = theme.extension<TableColors>() ?? TableColors.light;
    final w = size.width;
    final h = size.height;
    final diameter = h * 0.42;
    final radius = diameter / 2;
    final clothTop = h * 0.82;
    final centre = Offset(w * 0.64, clothTop - radius);

    // Point d'impact : sur le bord gauche de la bille, à la hauteur du procédé
    // (mi-rayon, comme le point bleu de `BallContactDiagram`).
    final dy = -tipHeightFactor(tipPoint) * radius * tipOffsetShare;
    final tip = Offset(
      centre.dx - math.sqrt(radius * radius - dy * dy),
      centre.dy + dy,
    );
    final elevation = cueElevation(cueHeight);
    final direction = Offset(math.cos(elevation), math.sin(elevation));
    final length = w * 0.5;
    final thickness = math.max<double>(6, radius * 0.28);
    final support = tip - direction * (diameter * 1.5);

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ScenePainter(
              bridge: bridge,
              clothTop: clothTop,
              support: support,
              cueThickness: thickness,
              diameter: diameter,
              scheme: theme.colorScheme,
              balls: balls,
              table: table,
            ),
          ),
        ),
        Positioned(
          left: centre.dx - radius,
          top: centre.dy - radius,
          width: diameter,
          height: diameter,
          child: BilliardBall(kind: BallKind.white, diameter: diameter),
        ),
        Positioned(
          left: tip.dx - length,
          top: tip.dy - thickness / 2,
          width: length,
          height: thickness,
          child: BilliardCue(
            length: length,
            thickness: thickness,
            angle: elevation,
          ),
        ),
      ],
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter({
    required this.bridge,
    required this.clothTop,
    required this.support,
    required this.cueThickness,
    required this.diameter,
    required this.scheme,
    required this.balls,
    required this.table,
  });

  final CueBridge? bridge;
  final double clothTop;
  final Offset support;
  final double cueThickness;
  final double diameter;
  final ColorScheme scheme;
  final BallColors balls;
  final TableColors table;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height * 0.06),
        ),
        Paint()..color = scheme.surfaceContainerHighest,
      )
      ..drawRect(
        Rect.fromLTRB(0, clothTop, size.width, size.height),
        Paint()..color = balls.cloth,
      );

    final kind = bridge;
    if (kind == null) return;
    final handTop = support.dy + cueThickness / 2;
    final handWidth = diameter * 0.7;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = table.cueButt;

    var handBottom = clothTop;
    if (kind == CueBridge.frame) {
      // Le rail est plus haut que le tapis : la main s'y appuie.
      final railTop = math.min(
        clothTop - diameter * 0.15,
        math.max(handTop + diameter * 0.2, handTop),
      );
      handBottom = railTop;
      final rail = Rect.fromLTRB(
        0,
        railTop,
        support.dx + handWidth,
        size.height,
      );
      canvas
        ..drawRect(rail, Paint()..color = table.rail)
        ..drawRect(rail, outline);
    }
    final hand = RRect.fromRectAndCorners(
      Rect.fromLTRB(
        support.dx - handWidth / 2,
        math.min(handTop, handBottom - diameter * 0.1),
        support.dx + handWidth / 2,
        handBottom,
      ),
      topLeft: Radius.circular(handWidth / 2),
      topRight: Radius.circular(handWidth / 2),
    );
    canvas
      ..drawRRect(hand, Paint()..color = scheme.surfaceContainerLowest)
      ..drawRRect(hand, outline);
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.bridge != bridge ||
      old.clothTop != clothTop ||
      old.support != support ||
      old.cueThickness != cueThickness ||
      old.diameter != diameter ||
      old.scheme != scheme ||
      old.balls != balls ||
      old.table != table;
}
