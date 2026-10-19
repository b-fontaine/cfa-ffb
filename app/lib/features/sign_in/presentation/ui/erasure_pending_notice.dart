import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Message sobre de l'écran de connexion quand l'effacement du cache local des
/// données du club, demandé par la déconnexion, n'a pas abouti (ADR 0024, C4) :
/// des données d'élèves restent sur l'appareil. Dit quoi faire (fermer les
/// autres onglets) et propose « Réessayer l'effacement ». Région vive : le
/// message est annoncé aux lecteurs d'écran. Aucun texte de donnée personnelle.
class ErasurePendingNotice extends StatelessWidget {
  const ErasurePendingNotice({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: AppRadii.mediumRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.signInErasurePendingMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onRetry,
                  child: Text(l10n.signInErasurePendingRetry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
