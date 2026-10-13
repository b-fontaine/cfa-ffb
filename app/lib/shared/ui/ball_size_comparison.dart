import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Comparaison de taille : la blanche et une bille de but côte à côte, posées
/// sur la même ligne et **à l'échelle** (48,0 mm contre 50,8 mm, rapport
/// 0,945 `[FFB]`). C'est la seule illustration où la différence se voit : sur
/// une table entière elle n'est que de 0,5 px à 360 px de large.
///
/// Les deux diamètres sont écrits sous les billes (texte, jamais la couleur
/// seule) et dits dans la description parlée.
class BallSizeComparison extends StatelessWidget {
  const BallSizeComparison({this.objectDiameter = 96, super.key});

  /// Diamètre d'une bille de but en pixels ; celui de la blanche en découle.
  final double objectDiameter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = NumberFormat(
      '0.0',
      Localizations.localeOf(context).toString(),
    );
    final cueMm = format.format(BlackballDimensions.cueBallDiameterMm);
    final objectMm = format.format(BlackballDimensions.objectBallDiameterMm);
    const ratio =
        BlackballDimensions.cueBallDiameterMm /
        BlackballDimensions.objectBallDiameterMm;
    return Semantics(
      label: l10n.ballSizeComparisonLabel(cueMm, objectMm),
      container: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            children: [
              _Item(
                kind: BallKind.white,
                diameter: objectDiameter * ratio,
                name: ballKindName(l10n, BallKind.white),
                size: l10n.ballSizeDiameter(cueMm),
              ),
              _Item(
                kind: BallKind.red,
                diameter: objectDiameter,
                name: ballKindName(l10n, BallKind.red),
                size: l10n.ballSizeDiameter(objectMm),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.ballSizeComparisonNote,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.kind,
    required this.diameter,
    required this.name,
    required this.size,
  });

  final BallKind kind;
  final double diameter;
  final String name;
  final String size;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BilliardBall(kind: kind, diameter: diameter, showLetter: false),
        const SizedBox(height: AppSpacing.xs),
        Text(name, style: style),
        Text(size, style: style),
      ],
    );
  }
}
