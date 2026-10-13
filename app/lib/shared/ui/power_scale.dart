import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Échelle de puissance de 1 à [levels] (5 au plus) : des barres de plus en
/// plus hautes, numérotées, dont une peut être mise en évidence.
///
/// Le niveau mis en évidence est reconnu à sa barre pleine, sa coche et sa
/// description parlée, pas à la seule couleur. [distanceLabel] est le texte
/// de repère fourni par la séance (déjà en français), écrit sous l'échelle.
class PowerScale extends StatelessWidget {
  const PowerScale({
    required this.levels,
    this.highlight,
    this.distanceLabel,
    super.key,
  }) : assert(levels >= 1 && levels <= 5, 'levels doit être entre 1 et 5'),
       assert(
         highlight == null || (highlight >= 1 && highlight <= levels),
         'highlight doit être dans 1..levels',
       );

  final int levels;
  final int? highlight;
  final String? distanceLabel;

  static const double _minBarHeight = 36;
  static const double _barRange = 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final base = highlight == null
        ? l10n.powerScaleRangeLabel(levels)
        : l10n.powerScaleLabel(highlight!, levels);
    final distance = distanceLabel;
    return Semantics(
      label: distance == null ? base : '$base. $distance',
      container: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var level = 1; level <= levels; level++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: _Bar(
                      level: level,
                      height: _minBarHeight + _barRange * level / levels,
                      selected: level == highlight,
                      scheme: scheme,
                      textStyle: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l10n.powerScaleWeak,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              Flexible(
                child: Text(
                  l10n.powerScaleStrong,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
          if (distance != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              distance,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.level,
    required this.height,
    required this.selected,
    required this.scheme,
    required this.textStyle,
  });

  final int level;
  final double height;
  final bool selected;
  final ColorScheme scheme;
  final TextStyle? textStyle;

  /// Hauteur réservée à la coche en haut de la barre.
  static const double _iconSlot = 18;

  @override
  Widget build(BuildContext context) {
    final fill = selected ? scheme.primary : scheme.secondaryContainer;
    final on = selected ? scheme.onPrimary : scheme.onSecondaryContainer;
    // Le numéro grandit avec le texte du système : la barre garde sa hauteur
    // proportionnelle au niveau tant qu'il y tient, puis s'allonge (jamais de
    // débordement à 200 %).
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(textStyle?.fontSize ?? 16) *
        (textStyle?.height ?? 1.4);
    final free = height - _iconSlot - AppSpacing.xs - lineHeight;
    return DecoratedBox(
      key: ValueKey('power-bar-$level'),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: scheme.primary, width: selected ? 3 : 1),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.small),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            Icon(
              Icons.check,
              key: const ValueKey('power-highlight'),
              size: _iconSlot,
              color: on,
            )
          else
            const SizedBox(height: _iconSlot),
          SizedBox(height: math.max(0, free)),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text('$level', style: textStyle?.copyWith(color: on)),
          ),
        ],
      ),
    );
  }
}
