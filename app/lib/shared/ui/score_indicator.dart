import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Score `x/n` : une pastille par essai (pleine = réussi, creuse = manqué)
/// et le texte « x/n ». L'information ne repose jamais sur la couleur seule.
class ScoreIndicator extends StatelessWidget {
  const ScoreIndicator({required this.score, required this.total, super.key})
    : assert(total > 0, 'total must be positive'),
      assert(score >= 0 && score <= total, 'score must be within 0..total');

  final int score;
  final int total;

  static const double _dotSize = 14;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.scoreOutOf(score, total),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Container(
                key: ValueKey(
                  i < score ? 'score-dot-filled' : 'score-dot-empty',
                ),
                width: _dotSize,
                height: _dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < score ? scheme.primary : Colors.transparent,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.xs),
          Text('$score/$total', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
