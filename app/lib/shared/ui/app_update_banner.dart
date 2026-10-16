import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Bannière sobre « nouvelle version disponible » (lot 15) : un message, une
/// action « Mettre à jour » et « Plus tard ». Annoncée aux lecteurs d'écran à
/// son apparition ; ne bloque rien (la saisie en cours continue).
class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({
    required this.onUpdate,
    required this.onLater,
    super.key,
  });

  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: colors.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            children: [
              Text(
                l10n.updateBannerMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: onLater,
                    child: Text(l10n.updateBannerLater),
                  ),
                  FilledButton(
                    onPressed: onUpdate,
                    child: Text(l10n.updateBannerAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
