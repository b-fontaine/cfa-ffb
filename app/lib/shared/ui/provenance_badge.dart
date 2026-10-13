import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Provenance d'un élément du contenu : pastille de la source (`[S]`, `[FFB]`,
/// `[Web]`) ou badge « Proposition » pour un `[Prop]`.
///
/// Le sens est porté par le texte et l'icône, jamais par la couleur seule ; un
/// `[Prop]` n'est jamais présenté comme une règle fédérale.
class ProvenanceBadge extends StatelessWidget {
  const ProvenanceBadge({required this.provenance, super.key});

  final Provenance provenance;

  /// Libellé localisé de la source d'une provenance sourcée.
  static String sourceLabel(AppLocalizations l10n, Provenance provenance) =>
      switch (provenance) {
        Provenance.s => l10n.provenanceS,
        Provenance.ffb => l10n.provenanceFfb,
        Provenance.web => l10n.provenanceWeb,
        Provenance.prop => l10n.proposalBadge,
      };

  @override
  Widget build(BuildContext context) {
    if (provenance.isProposal) return const ProposalBadge();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
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
            ExcludeSemantics(
              child: Icon(
                Icons.verified_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                sourceLabel(l10n, provenance),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
