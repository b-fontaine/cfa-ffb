import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/ball_chip.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/app_typography.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

/// Couleurs d'une bille selon son groupe.
extension BallKindColors on BallColors {
  /// Couleur de la bille.
  Color fillOf(BallKind kind) => switch (kind) {
    BallKind.red => red,
    BallKind.yellow => yellow,
    BallKind.black => black,
    BallKind.white => white,
  };

  /// Couleur du texte posé sur la bille.
  Color onFillOf(BallKind kind) => switch (kind) {
    BallKind.red => onRed,
    BallKind.yellow => onYellow,
    BallKind.black => onBlack,
    BallKind.white => onWhite,
  };
}

/// Nom localisé d'une bille (« Bille rouge »…).
String ballKindName(AppLocalizations l10n, BallKind kind) => switch (kind) {
  BallKind.red => l10n.ballRed,
  BallKind.yellow => l10n.ballYellow,
  BallKind.black => l10n.ballBlack,
  BallKind.white => l10n.ballWhite,
};

/// Lettre localisée d'une bille (R/J/N/B ou R/Y/B/W).
String ballKindLetter(AppLocalizations l10n, BallKind kind) => switch (kind) {
  BallKind.red => l10n.ballRedLetter,
  BallKind.yellow => l10n.ballYellowLetter,
  BallKind.black => l10n.ballBlackLetter,
  BallKind.white => l10n.ballWhiteLetter,
};

/// Peint une bille (ombre, dégradé, reflet léger) centrée en [center].
void paintBilliardBall(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required Color fill,
  required BallColors balls,
  required TableColors table,
}) {
  if (radius <= 0) return;
  final shadow = Paint()
    ..color = table.pocket.withValues(alpha: 0.28)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.35);
  canvas.drawCircle(
    center + Offset(radius * 0.12, radius * 0.2),
    radius,
    shadow,
  );

  final body = Rect.fromCircle(center: center, radius: radius);
  final gradient = RadialGradient(
    center: const Alignment(-0.35, -0.4),
    radius: 0.95,
    colors: [
      Color.lerp(fill, balls.white, 0.45)!,
      fill,
      Color.lerp(fill, balls.black, 0.4)!,
    ],
    stops: const [0, 0.55, 1],
  );
  canvas
    ..drawCircle(center, radius, Paint()..shader = gradient.createShader(body))
    ..drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.75, radius * 0.08)
        ..color = table.pocket.withValues(alpha: 0.55),
    );

  final glint = Rect.fromCenter(
    center: center + Offset(-radius * 0.35, -radius * 0.4),
    width: radius * 0.55,
    height: radius * 0.35,
  );
  canvas.drawOval(glint, Paint()..color = balls.white.withValues(alpha: 0.55));
}

/// Bille de billard peinte (dégradé, reflet) avec nom parlé localisé.
///
/// Le diamètre vient de [diameter] (pixels) ou, à défaut, de [geometry] (une
/// bille de la table). À partir de 28 px, la bille porte sa lettre (R/J/N/B)
/// ou son [label] ; en dessous, le [label] est posé à côté de la bille. Sur une
/// table réduite, la bille reste identifiée par son nom parlé et par la
/// légende de l'exercice : la couleur n'est jamais le seul indice.
class BilliardBall extends StatelessWidget {
  const BilliardBall({
    required this.kind,
    this.geometry,
    this.diameter,
    this.label,
    this.showLetter = true,
    super.key,
  }) : assert(
         geometry != null || diameter != null,
         'Fournir `diameter` ou `geometry`.',
       );

  final BallKind kind;

  /// Géométrie de la table : le diamètre est celui d'une bille.
  final TableGeometry? geometry;

  /// Diamètre en pixels (prioritaire sur [geometry]).
  final double? diameter;

  /// Numéro ou libellé de la bille (« 3 », « x4 »).
  final String? label;

  /// Affiche la lettre de la bille quand elle tient dedans et sans [label].
  final bool showLetter;

  static const double _insideThreshold = 28;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final table = theme.extension<TableColors>() ?? TableColors.light;
    final size = diameter ?? geometry!.ballRadiusPx * 2;
    final name = ballKindName(l10n, kind);
    final text = label ?? (showLetter ? ballKindLetter(l10n, kind) : null);
    final inside = size >= _insideThreshold;
    final style = theme.textTheme.labelSmall;
    return Semantics(
      label: label == null ? name : l10n.ballWithLabel(name, label!),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BallPainter(
                  fill: balls.fillOf(kind),
                  balls: balls,
                  table: table,
                ),
              ),
            ),
            if (text != null && inside)
              Positioned.fill(
                child: Center(
                  child: Text(
                    text,
                    style: style?.copyWith(
                      color: balls.onFillOf(kind),
                      fontSize: math.max(
                        AppTypography.minTextSize,
                        size * 0.45,
                      ),
                    ),
                  ),
                ),
              ),
            if (label != null && !inside)
              Positioned(
                left: size + 2,
                top: size * 0.5,
                child: Text(
                  label!,
                  softWrap: false,
                  style: style?.copyWith(color: balls.onCloth),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BallPainter extends CustomPainter {
  const _BallPainter({
    required this.fill,
    required this.balls,
    required this.table,
  });

  final Color fill;
  final BallColors balls;
  final TableColors table;

  @override
  void paint(Canvas canvas, Size size) => paintBilliardBall(
    canvas,
    center: size.center(Offset.zero),
    radius: size.shortestSide / 2,
    fill: fill,
    balls: balls,
    table: table,
  );

  @override
  bool shouldRepaint(_BallPainter old) =>
      old.fill != fill || old.balls != balls || old.table != table;
}
