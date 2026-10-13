import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:flutter/material.dart';

export 'package:billard_cfa/shared/ui/ball_kind.dart';

/// Pastille de bille : couleur **et** lettre (R/J/N/B), jamais la couleur seule.
class BallChip extends StatelessWidget {
  const BallChip({required this.kind, this.size = 40, super.key});

  final BallKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final balls = theme.extension<BallColors>() ?? BallColors.light;
    final (fill, onFill, letter, name) = switch (kind) {
      BallKind.red => (
        balls.red,
        balls.onRed,
        l10n.ballRedLetter,
        l10n.ballRed,
      ),
      BallKind.yellow => (
        balls.yellow,
        balls.onYellow,
        l10n.ballYellowLetter,
        l10n.ballYellow,
      ),
      BallKind.black => (
        balls.black,
        balls.onBlack,
        l10n.ballBlackLetter,
        l10n.ballBlack,
      ),
      BallKind.white => (
        balls.white,
        balls.onWhite,
        l10n.ballWhiteLetter,
        l10n.ballWhite,
      ),
    };
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: theme.colorScheme.outline, width: 2),
          ),
          child: Center(
            child: Text(
              letter,
              style: theme.textTheme.labelLarge?.copyWith(color: onFill),
            ),
          ),
        ),
      ),
    );
  }
}
