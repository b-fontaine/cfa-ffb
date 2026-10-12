import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';

/// Ton d'un statut : l'icône et le libellé portent le sens, la couleur
/// l'appuie seulement.
enum BadgeTone { success, attention, neutral }

/// Pastille de statut : icône + libellé (jamais la couleur seule).
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.tone, required this.label, super.key});

  final BadgeTone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = theme.extension<StatusColors>() ?? StatusColors.light;
    final scheme = theme.colorScheme;
    final (background, foreground, icon) = switch (tone) {
      BadgeTone.success => (
        status.success,
        status.onSuccess,
        Icons.check_circle_outline,
      ),
      BadgeTone.attention => (
        status.attention,
        status.onAttention,
        Icons.warning_amber_rounded,
      ),
      BadgeTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        Icons.radio_button_unchecked,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.smallRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 16, color: foreground)),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
