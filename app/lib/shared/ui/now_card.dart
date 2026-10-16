import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Carte d'une chose à faire maintenant (séance en cours, prochaine séance) :
/// étiquette d'état (icône et texte, jamais la couleur seule), titre, lignes
/// de méta, action principale et action secondaire.
///
/// Composant sans dépendance métier : le parent fournit les libellés. Chaque
/// carte est un groupe sémantique (état, titre, méta) ; les actions gardent
/// leur propre sémantique et mesurent au moins 48 dp. Pas de rouge d'état :
/// la mise en avant `high` prend le bord bleu-tapis (ADR 0010).
class NowCard extends StatelessWidget {
  const NowCard({
    required this.stateLabel,
    required this.stateIcon,
    required this.title,
    this.meta = const [],
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.emphasis = SectionEmphasis.medium,
    super.key,
  });

  /// État (« En cours », « Prochaine ») et son icône.
  final String stateLabel;
  final IconData stateIcon;
  final String title;

  /// Lignes sous le titre (date, groupe, étape…).
  final List<String> meta;

  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final SectionEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final side = switch (emphasis) {
      SectionEmphasis.low => BorderSide.none,
      SectionEmphasis.medium => BorderSide(color: scheme.outlineVariant),
      SectionEmphasis.high => BorderSide(color: scheme.secondary, width: 2),
    };
    final primary = primaryLabel;
    final secondary = secondaryLabel;
    return Card(
      color: emphasis == SectionEmphasis.low
          ? scheme.surfaceContainerLow
          : scheme.surfaceContainer,
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
              container: true,
              label: [stateLabel, title, ...meta].join(', '),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(stateIcon, size: 20, color: scheme.secondary),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            stateLabel,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(title, style: theme.textTheme.titleMedium),
                    for (final line in meta)
                      Text(line, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            if (primary != null || secondary != null) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (primary != null)
                    FilledButton(onPressed: onPrimary, child: Text(primary)),
                  if (secondary != null)
                    OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondary),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
