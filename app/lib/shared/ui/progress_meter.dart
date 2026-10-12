import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Jauge de progression : barre et texte (le texte porte la valeur, jamais la
/// barre seule). `semanticLabel` est lu à la place du dessin.
class ProgressMeter extends StatelessWidget {
  const ProgressMeter({
    required this.value,
    required this.maximum,
    required this.label,
    super.key,
  }) : assert(maximum > 0, 'maximum must be positive'),
       assert(
         value >= 0 && value <= maximum,
         'value must be within 0..maximum',
       );

  final int value;
  final int maximum;

  /// Texte affiché sous la barre (ex. « 25 % validé »).
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: AppRadii.smallRadius,
            child: LinearProgressIndicator(
              value: value / maximum,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
