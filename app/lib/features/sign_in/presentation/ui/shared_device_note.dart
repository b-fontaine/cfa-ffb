import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Avertissement « appareil partagé » de l'écran de connexion (ADR 0024, C4) :
/// les données du club restent sur l'appareil pour le mode hors ligne, jusqu'à
/// la déconnexion. Sobre : une icône d'information et une phrase, jamais une
/// alerte (rien n'est en erreur).
class SharedDeviceNote extends StatelessWidget {
  const SharedDeviceNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            AppLocalizations.of(context).signInSharedDevice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
