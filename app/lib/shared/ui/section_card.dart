import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Niveau de mise en avant d'une carte (hiérarchie de surfaces, R2).
///
/// - [low] : carte de contenu, `surfaceContainerLow`, sans bord ;
/// - [medium] : `surfaceContainer` et bord `outlineVariant` ;
/// - [high] : carte en évidence (étape courante, élève en cours de saisie,
///   alerte), `surfaceContainer` et bord bleu-tapis (`secondary`) de 2 dp.
///
/// Le niveau ne porte jamais seul le sens : le titre reste l'en-tête
/// sémantique de la carte.
enum SectionEmphasis { low, medium, high }

/// Carte de section : titre (en-tête sémantique) et contenu.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.emphasis = SectionEmphasis.low,
    super.key,
  });

  final String title;
  final Widget child;
  final SectionEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (color, side) = switch (emphasis) {
      SectionEmphasis.low => (scheme.surfaceContainerLow, BorderSide.none),
      SectionEmphasis.medium => (
        scheme.surfaceContainer,
        BorderSide(color: scheme.outlineVariant),
      ),
      SectionEmphasis.high => (
        scheme.surfaceContainer,
        BorderSide(color: scheme.secondary, width: 2),
      ),
    };
    return Card(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mediumRadius,
        side: side,
      ),
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}
