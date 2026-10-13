import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Renvoi au PDF fédéral : « Voir la page n du PDF » et le nom du fichier.
///
/// Texte seul : jamais d'image du PDF, et rien à toucher (les PDF sont lus en
/// dehors de l'application).
class PdfPageChip extends StatelessWidget {
  const PdfPageChip({required this.file, required this.page, super.key});

  /// Nom du fichier source (tel qu'écrit dans la séance).
  final String file;

  /// Numéro de page du PDF.
  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final reference = l10n.pdfPageRef(page);
    return Semantics(
      label: l10n.pdfPageChipLabel(reference, file),
      container: true,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
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
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reference,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      file,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
