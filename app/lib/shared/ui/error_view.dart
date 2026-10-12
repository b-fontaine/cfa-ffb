import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Erreur de chargement : message explicite et action « Réessayer ».
class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final onRetry = this.onRetry;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              header: true,
              child: Text(
                l10n.commonErrorTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
            ],
          ],
        ),
      ),
    );
  }
}
