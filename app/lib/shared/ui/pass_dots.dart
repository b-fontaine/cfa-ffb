import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Résultat d'une série d'essais : `total` pastilles tapables (pleine =
/// empochée, creuse = manquée) suivies du texte « x/n ».
///
/// [value] porte l'issue de chaque essai, dans l'ordre : l'ordre des passages
/// compte pour le suivi (U5). Les essais absents de [value] sont manqués.
/// Taper la pastille `k` appelle [onChanged] avec la liste complète (longueur
/// [total]) où seul l'essai `k` a basculé. Sans [onChanged], ou en
/// [readOnly], les pastilles ne réagissent pas ; sans [onChanged] et hors
/// [readOnly] elles sont en plus atténuées (état désactivé).
///
/// Jamais la couleur seule : pleine avec une coche, ou creuse avec un
/// contour. Chaque pastille offre une cible de 48 dp ; la rangée passe à la
/// ligne quand `total` est grand.
class PassDots extends StatelessWidget {
  const PassDots({
    required this.value,
    required this.total,
    this.onChanged,
    this.readOnly = false,
    super.key,
  }) : assert(total > 0, 'total must be positive');

  final List<bool> value;
  final int total;
  final ValueChanged<List<bool>>? onChanged;
  final bool readOnly;

  static const double _dotSize = 28;
  static const double _disabledOpacity = 0.38;

  bool _pocketed(int index) => index < value.length && value[index];

  void _toggle(int index) {
    final next = [for (var i = 0; i < total; i++) _pocketed(i)];
    next[index] = !next[index];
    onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    assert(value.length <= total, 'value must not exceed total');
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    final interactive = !readOnly && onChanged != null;
    final disabled = !readOnly && onChanged == null;
    final score = [for (var i = 0; i < total; i++) _pocketed(i)]
        .where((pocketed) => pocketed)
        .length;
    final row = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Semantics(
            button: true,
            enabled: interactive,
            label: _pocketed(i)
                ? l10n.passDotsPocketed(i + 1, total)
                : l10n.passDotsMissed(i + 1, total),
            excludeSemantics: true,
            child: InkResponse(
              key: ValueKey('pass-dot-${i + 1}'),
              onTap: interactive ? () => _toggle(i) : null,
              radius: AppSpacing.minTouchTarget / 2,
              child: SizedBox.square(
                dimension: AppSpacing.minTouchTarget,
                child: Center(
                  child: Container(
                    key: ValueKey(
                      _pocketed(i) ? 'pass-dot-filled' : 'pass-dot-empty',
                    ),
                    width: _dotSize,
                    height: _dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _pocketed(i)
                          ? scheme.secondary
                          : Colors.transparent,
                      border: Border.all(color: scheme.secondary, width: 2),
                    ),
                    child: _pocketed(i)
                        ? Icon(Icons.check, size: 18, color: scheme.onSecondary)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: ExcludeSemantics(
            child: Text('$score/$total', style: theme.textTheme.labelLarge),
          ),
        ),
      ],
    );
    return Semantics(
      container: true,
      label: l10n.passDotsSummary(score, total),
      child: disabled ? Opacity(opacity: _disabledOpacity, child: row) : row,
    );
  }
}
