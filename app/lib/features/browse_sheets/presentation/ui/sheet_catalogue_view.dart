import 'package:billard_cfa/entities/session_sheet/domain/needs_review.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_sources.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/french_content_notice.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/provenance_badge.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Le catalogue de séances, une section par technique et une ligne par
/// séance (« Séance 2/2 »). Lecture seule : ouvrir une ligne ouvre le détail.
///
/// Une séance contenant du contenu `[Prop]` porte le badge « Proposition » et,
/// pour chaque motif (jeu, règle de lien, exercices, théorie…), un indicateur
/// « à valider » qui dit QUOI valider. Le filtre [filter] ne garde que les
/// séances à valider ou celles dont le jeu est à valider (le décompte « k/n »
/// reste celui de la technique entière) ; [onFilter] le choisit ou le retire.
class SheetCatalogueView extends StatelessWidget {
  const SheetCatalogueView({
    required this.catalogue,
    required this.filter,
    required this.onFilter,
    required this.onOpenSheet,
    super.key,
  });

  final SheetCatalogue catalogue;
  final SheetReviewFilter filter;
  final ValueChanged<SheetReviewFilter> onFilter;
  final ValueChanged<SheetId> onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FrenchContentNotice(),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.catalogueSummary(catalogue.techniqueCount, catalogue.sheetCount),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilterChip(
              label: Text(l10n.catalogueFilterToReview),
              selected: filter == SheetReviewFilter.toReview,
              onSelected: (_) => onFilter(SheetReviewFilter.toReview),
            ),
            FilterChip(
              label: Text(l10n.catalogueFilterGames),
              selected: filter == SheetReviewFilter.games,
              onSelected: (_) => onFilter(SheetReviewFilter.games),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (catalogue.groups.isEmpty)
          Text(switch (filter) {
            SheetReviewFilter.none => l10n.catalogueEmpty,
            SheetReviewFilter.toReview => l10n.catalogueNoneToReview,
            SheetReviewFilter.games => l10n.catalogueNoneGames,
          }, style: theme.textTheme.bodyLarge),
        for (final group in catalogue.groups) ...[
          _TechniqueSection(group: group, onOpenSheet: onOpenSheet),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _TechniqueSection extends StatelessWidget {
  const _TechniqueSection({required this.group, required this.onOpenSheet});

  final TechniqueGroup group;
  final ValueChanged<SheetId> onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.catalogueTechniqueHeading(group.rank, group.title),
                  key: ValueKey('technique:${group.technique}'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            for (final sheet in group.sheets)
              _SheetTile(
                sheet: sheet,
                partCount: group.partCount,
                onOpen: () => onOpenSheet(sheet.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.sheet,
    required this.partCount,
    required this.onOpen,
  });

  final SessionSheet sheet;
  final int partCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reasons = reviewReasonsOf(sheet);
    return ListTile(
      key: ValueKey('sheet:${sheet.id.value}'),
      minVerticalPadding: AppSpacing.sm,
      onTap: onOpen,
      title: Text(l10n.sheetPartLabel(sheet.part, partCount)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sheet.theme.name),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final source in sourcedProvenances(sheet))
                  ProvenanceBadge(provenance: source),
                if (reasons.any((reason) => reason.counts))
                  const ProposalBadge(),
                for (final reason in reasons)
                  StatusBadge(
                    key: ValueKey('review:${sheet.id.value}:${reason.name}'),
                    tone: reason.counts
                        ? BadgeTone.attention
                        : BadgeTone.neutral,
                    label: _reasonLabel(l10n, reason),
                  ),
              ],
            ),
          ],
        ),
      ),
      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
    );
  }
}

String _reasonLabel(AppLocalizations l10n, ReviewReason reason) =>
    switch (reason) {
      ReviewReason.game => l10n.catalogueReasonGame,
      ReviewReason.gameLink => l10n.catalogueReasonGameLink,
      ReviewReason.exercise => l10n.catalogueReasonExercise,
      ReviewReason.initiation => l10n.catalogueReasonInitiation,
      ReviewReason.theory => l10n.catalogueReasonTheory,
      ReviewReason.recall => l10n.catalogueReasonRecall,
    };
