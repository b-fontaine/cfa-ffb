import 'dart:math' as math;

import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Saisie d'un petit nombre entier par deux boutons (cibles ≥ 48 dp) : plus
/// sûre qu'un clavier au bord d'une table de billard. La valeur reste dans
/// `[min, max]` ; chaque appui la déplace au multiple de [step] suivant ou
/// précédent (ramené à la borne), de sorte qu'une valeur importée hors grille
/// retrouve la grille.
class CounterField extends StatelessWidget {
  const CounterField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.decreaseTooltip,
    required this.increaseTooltip,
    this.min = 0,
    this.max = 99,
    this.step = 1,
    super.key,
  }) : assert(min <= max, 'min must not exceed max'),
       assert(step >= 1, 'step must be positive');

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String decreaseTooltip;
  final String increaseTooltip;
  final int min;
  final int max;
  final int step;

  /// Multiple de [step] strictement inférieur à [value].
  int get _previous => value % step == 0 ? value - step : value - value % step;

  /// Multiple de [step] strictement supérieur à [value].
  int get _next => (value ~/ step + 1) * step;

  static final ButtonStyle _buttonStyle = IconButton.styleFrom(
    minimumSize: const Size.square(AppSpacing.minTouchTarget),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: label,
      value: '$value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                style: _buttonStyle,
                tooltip: decreaseTooltip,
                onPressed: value > min
                    ? () => onChanged(math.max(min, _previous))
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: AppSpacing.minTouchTarget,
                child: ExcludeSemantics(
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton.filledTonal(
                style: _buttonStyle,
                tooltip: increaseTooltip,
                onPressed: value < max
                    ? () => onChanged(math.min(max, _next))
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
