import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';

/// Niveau d'une alerte : `attention` (à surveiller) ou `persistent` (bloquant
/// tant que non traité).
enum AlertLevel { attention, persistent }

/// Alerte : icône, libellé de niveau et message (jamais la couleur seule).
class AppAlert extends StatelessWidget {
  const AppAlert({required this.level, required this.message, super.key});

  final AlertLevel level;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final status = theme.extension<StatusColors>() ?? StatusColors.light;
    final (background, foreground, icon, label) = switch (level) {
      AlertLevel.attention => (
        status.attention,
        status.onAttention,
        Icons.warning_amber_rounded,
        l10n.alertAttention,
      ),
      AlertLevel.persistent => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
        Icons.error_outline,
        l10n.alertPersistent,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.mediumRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, color: foreground)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
