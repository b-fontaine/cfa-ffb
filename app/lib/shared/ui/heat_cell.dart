import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';

/// Palier de « chaleur » d'une cellule technique × élève : aucun exercice,
/// moins de la moitié, au moins la moitié sans tout, tout. Quatre teintes de
/// bleu-tapis (jamais de rouge d'état, ADR 0010), toujours doublées de la
/// fraction écrite.
enum HeatLevel { none, some, most, all }

/// Cellule de la carte de chaleur d'un groupe, de 56 × 56 dp.
///
/// [fraction] (« 3/4 ») est toujours écrite ; [label] est le nom accessible
/// complet (élève, technique, fraction, état). [level] teinte le fond, une
/// coche marque une technique terminée, [acquired] un drapeau (acquis au
/// positionnement) et [alerted] une icône d'attention.
class HeatCell extends StatelessWidget {
  const HeatCell({
    required this.fraction,
    required this.level,
    required this.label,
    this.acquired = false,
    this.alerted = false,
    this.onTap,
    super.key,
  });

  /// Côté de la cellule (au moins la cible tactile de 48 dp).
  static const double size = 56;

  final String fraction;
  final HeatLevel level;
  final String label;
  final bool acquired;
  final bool alerted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = theme.extension<StatusColors>() ?? StatusColors.light;
    final (fill, foreground) = switch (level) {
      HeatLevel.none => (scheme.surface, scheme.onSurface),
      HeatLevel.some => (
        Color.alphaBlend(
          scheme.secondary.withValues(alpha: 0.18),
          scheme.surface,
        ),
        scheme.onSurface,
      ),
      HeatLevel.most => (
        Color.alphaBlend(
          scheme.secondary.withValues(alpha: 0.40),
          scheme.surface,
        ),
        scheme.onSurface,
      ),
      HeatLevel.all => (scheme.secondary, scheme.onSecondary),
    };
    final body = Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              key: ValueKey('heat-fill-${level.name}'),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: AppRadii.smallRadius,
                border: Border.all(
                  color: level == HeatLevel.none
                      ? scheme.outlineVariant
                      : scheme.secondary,
                ),
              ),
              child: Stack(
                children: [
                  if (level == HeatLevel.all || acquired)
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Icon(
                        acquired ? Icons.bookmark_added : Icons.check,
                        size: 12,
                        color: foreground,
                      ),
                    ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          fraction,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (alerted)
            Positioned(
              top: -3,
              right: -3,
              child: DecoratedBox(
                key: const ValueKey('heat-marker-alert'),
                decoration: BoxDecoration(
                  color: status.attention,
                  shape: BoxShape.circle,
                  border: Border.all(color: status.onAttention),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Icon(
                    Icons.priority_high,
                    size: 12,
                    color: status.onAttention,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox.square(
        dimension: size,
        child: onTap == null
            ? body
            : InkResponse(onTap: onTap, radius: size / 2, child: body),
      ),
    );
  }
}
