import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Bandeau discret « Tournez l'appareil » : la largeur borne le schéma, un
/// appareil tenu en paysage l'agrandirait. Il n'empêche rien : le schéma reste
/// utilisable, [onDismiss] retire le bandeau. Annoncé une fois (région vive),
/// teinte bleu-tapis sans rouge (ADR 0010).
class RotateHint extends StatelessWidget {
  const RotateHint({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: AppRadii.mediumRadius,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.screen_rotation, color: scheme.onSecondaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.presentationRotateHint,
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.presentationRotateDismiss,
              onPressed: onDismiss,
              color: scheme.onSecondaryContainer,
              constraints: const BoxConstraints(
                minWidth: AppSpacing.minTouchTarget,
                minHeight: AppSpacing.minTouchTarget,
              ),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
