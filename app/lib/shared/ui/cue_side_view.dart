import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
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
import 'package:intl/intl.dart';

export 'package:billard_cfa/shared/lib/player_figure_layout.dart'
    show CueBridge;

/// Vue de côté de la blanche et de la queue : hauteur du talon, point
/// d'impact vertical du procédé et appui du chevalet.
///
/// Schéma non à l'échelle `[Prop]`. De côté, un impact à gauche ou à droite ne
/// se voit pas : il est dessiné à hauteur du centre ; le point exact est dit
/// dans la description parlée.
///
/// Avec [showContact], une bille de but touche la blanche : toutes deux posées
/// sur le tapis, le contact est **légèrement au-dessus de l'équateur de la
/// blanche** (fiche n° 4 `[S]` : 0,68 mm en réalité). L'écart de taille est
/// exagéré [contactExaggeration] fois pour être visible, et la légende le dit.
class CueSideView extends StatelessWidget {
  const CueSideView({
    required this.tipPoint,
    required this.cueHeight,
    this.bridge,
    this.showContact = false,
    super.key,
  });

  final TipPoint tipPoint;
  final CueHeight cueHeight;

  /// Dessine une bille de but au contact de la blanche, avec l'équateur de la
  /// blanche et le point de contact.
  final bool showContact;

  /// Facteur d'exagération de l'écart de rayon entre la blanche et la bille de
  /// but dans la vue de côté.
  static const double contactExaggeration = 10;

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
    final format = NumberFormat(
      '0.0',
      Localizations.localeOf(context).toString(),
    );
    final contactNote = showContact
        ? l10n.cueSideContactNote(
            format.format(BlackballDimensions.cueBallDiameterMm),
            format.format(BlackballDimensions.objectBallDiameterMm),
          )
        : null;
    final base = bridgeName == null
        ? l10n.cueSideLabel(height, tip)
        : l10n.cueSideLabelWithBridge(height, tip, bridgeName);
    return Semantics(
      label: contactNote == null ? base : '$base $contactNote',
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
                showContact: showContact,
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
          if (contactNote != null)
            Text(
              contactNote,
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

/// Rayon du repère du point de contact, en pixels.
const double _markerRadius = 5;

class _Scene extends StatelessWidget {
  const _Scene({
    required this.size,
    required this.tipPoint,
    required this.cueHeight,
    required this.bridge,
    required this.showContact,
  });

  final Size size;
  final TipPoint tipPoint;
  final CueHeight cueHeight;
  final CueBridge? bridge;
  final bool showContact;

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
    // Avec la bille de but à droite, la blanche est décalée vers la gauche.
    final centre = Offset(w * (showContact ? 0.5 : 0.64), clothTop - radius);

    // Bille de but posée sur le même tapis : rayon exagéré (écart x10), centre
    // plus haut que celui de la blanche, contact au-dessus de l'équateur.
    final objectRadius =
        radius *
        exaggeratedObjectRadius(
          cueRadius: BlackballDimensions.cueBallDiameterMm / 2,
          objectRadius: BlackballDimensions.objectBallDiameterMm / 2,
          factor: CueSideView.contactExaggeration,
        ) /
        (BlackballDimensions.cueBallDiameterMm / 2);
    final objectCentre = Offset(
      centre.dx + 2 * math.sqrt(radius * objectRadius),
      clothTop - objectRadius,
    );
    final contactGeometry = contactHeight(
      cueRadius: radius,
      objectRadius: objectRadius,
    );
    final contact =
        centre +
        Offset(
          radius * math.cos(contactGeometry.tilt),
          -radius * math.sin(contactGeometry.tilt),
        );

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
        if (showContact) ...[
          Positioned(
            left: objectCentre.dx - objectRadius,
            top: objectCentre.dy - objectRadius,
            width: objectRadius * 2,
            height: objectRadius * 2,
            child: BilliardBall(kind: BallKind.red, diameter: objectRadius * 2),
          ),
          Positioned(
            key: const ValueKey('cue-side-contact'),
            left: contact.dx - _markerRadius,
            top: contact.dy - _markerRadius,
            width: _markerRadius * 2,
            height: _markerRadius * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: table.chalk,
                border: Border.all(
                  color: theme.colorScheme.onSurface,
                  width: 2,
                ),
              ),
            ),
          ),
          // Équateur de la blanche, peint par-dessus les billes : c'est lui qui
          // montre que le contact est au-dessus de l'axe horizontal.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('cue-side-equator'),
                painter: _EquatorPainter(
                  from: Offset(centre.dx - radius * 1.25, centre.dy),
                  to: Offset(contact.dx + radius * 0.6, centre.dy),
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
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
      ..drawRRect(hand, Paint()..color = scheme.secondaryContainer)
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

/// Équateur de la blanche : trait horizontal pointillé, peint au-dessus des
/// billes.
class _EquatorPainter extends CustomPainter {
  const _EquatorPainter({
    required this.from,
    required this.to,
    required this.color,
  });

  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 2;
    final length = (to - from).distance;
    const dash = 6.0;
    for (var d = 0.0; d < length; d += dash * 2) {
      final a = from + (to - from) * (d / length);
      final b = from + (to - from) * (math.min(d + dash, length) / length);
      canvas.drawLine(a, b, line);
    }
  }

  @override
  bool shouldRepaint(_EquatorPainter old) =>
      old.from != from || old.to != to || old.color != color;
}
