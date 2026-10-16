import 'package:billard_cfa/entities/session_sheet/domain/needs_review.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_row.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/review_labels.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/group_choice.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/journey_mark.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/french_content_notice.dart';
import 'package:billard_cfa/shared/ui/journey_marker.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Le catalogue de séances, une section par technique et une ligne par
/// séance : le nom évocateur en titre, « Séance 2/2 · technique » en
/// sous-titre, **au plus un** badge « n points à valider » (détail en
/// infobulle et dans la sémantique). Ouvrir une ligne ouvre le détail.
///
/// Le nom évocateur est une proposition `[Prop]` : l'en-tête le dit une fois
/// plutôt que de répéter un badge vrai partout. La source fédérale n'est plus
/// dans la liste (elle reste dans le détail).
///
/// Le filtre [filter] ne garde que les séances à valider ou celles dont le
/// jeu est à valider (le décompte « k/n » reste celui de la technique
/// entière) ; [onFilter] le choisit ou le retire. Avec des [groups],
/// l'animateur suit le parcours d'un groupe : chaque séance de [marks] porte
/// un marqueur (faite, recommandée ensuite, à venir) ; sans groupe choisi,
/// aucune colonne de marqueurs.
class SheetCatalogueView extends StatelessWidget {
  const SheetCatalogueView({
    required this.catalogue,
    required this.filter,
    required this.onFilter,
    required this.onOpenSheet,
    this.groups = const [],
    this.selectedGroup,
    this.onGroupSelected,
    this.marks = const {},
    this.noStudents = false,
    this.journeyFailure,
    super.key,
  });

  final SheetCatalogue catalogue;
  final SheetReviewFilter filter;
  final ValueChanged<SheetReviewFilter> onFilter;
  final ValueChanged<SheetId> onOpenSheet;

  /// Les groupes proposés au sélecteur de parcours ; vide : pas de sélecteur.
  final List<GroupChoice> groups;
  final GroupId? selectedGroup;

  /// Choisit un groupe, ou `null` pour « Aucun groupe ».
  final ValueChanged<GroupId?>? onGroupSelected;

  /// Le marqueur de chaque séance pour le groupe choisi ; vide sans groupe.
  final Map<SheetId, JourneyMark> marks;

  /// Le groupe choisi n'a aucun élève : seules les séances faites sont
  /// marquées.
  final bool noStudents;

  /// Échec du calcul du parcours : dit sous le sélecteur, sans page d'erreur.
  final Failure? journeyFailure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final journeyFailure = this.journeyFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FrenchContentNotice(),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.catalogueNamesNote, style: theme.textTheme.bodyMedium),
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
        if (groups.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _GroupSelector(
            groups: groups,
            selected: selectedGroup,
            onSelected: onGroupSelected,
          ),
        ],
        if (marks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          const _Legend(),
        ],
        if (noStudents) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.catalogueJourneyNoStudents,
            key: const ValueKey('catalogue-journey-no-students'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (journeyFailure != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            failureMessage(l10n, journeyFailure),
            key: const ValueKey('catalogue-journey-failure'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (catalogue.groups.isEmpty)
          Text(switch (filter) {
            SheetReviewFilter.none => l10n.catalogueEmpty,
            SheetReviewFilter.toReview => l10n.catalogueNoneToReview,
            SheetReviewFilter.games => l10n.catalogueNoneGames,
          }, style: theme.textTheme.bodyLarge),
        for (final group in catalogue.groups) ...[
          _TechniqueSection(
            group: group,
            marks: marks,
            onOpenSheet: onOpenSheet,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final List<GroupChoice> groups;
  final GroupId? selected;
  final ValueChanged<GroupId?>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.catalogueGroupLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              key: const ValueKey('catalogue-group:none'),
              label: Text(l10n.catalogueGroupNone),
              selected: selected == null,
              onSelected: (_) => onSelected?.call(null),
            ),
            for (final group in groups)
              ChoiceChip(
                key: ValueKey('catalogue-group:${group.id.value}'),
                label: Text(group.name),
                selected: selected == group.id,
                onSelected: (_) => onSelected?.call(group.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// Légende des trois marqueurs, posée sous le sélecteur de groupe.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        for (final mark in JourneyMark.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(JourneyMarker.iconOf(mark), size: 20),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  JourneyMarker.labelOf(l10n, mark),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _TechniqueSection extends StatelessWidget {
  const _TechniqueSection({
    required this.group,
    required this.marks,
    required this.onOpenSheet,
  });

  final TechniqueGroup group;
  final Map<SheetId, JourneyMark> marks;
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
            for (final row in group.rows)
              _SheetTile(
                row: row,
                mark: marks[row.id],
                onOpen: () => onOpenSheet(row.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.row,
    required this.mark,
    required this.onOpen,
  });

  final SheetRow row;
  final JourneyMark? mark;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = row.id.value;
    final mark = this.mark;
    return ListTile(
      key: ValueKey('sheet:$id'),
      minVerticalPadding: AppSpacing.sm,
      onTap: onOpen,
      leading: mark == null
          ? null
          : JourneyMarker(key: ValueKey('mark:$id'), mark: mark),
      title: Text(
        row.hasName ? row.name : l10n.sheetPartLabel(row.part, row.partCount),
        key: ValueKey('sheet-title:$id'),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.catalogueRowSubtitle(row.part, row.partCount, row.technique),
            key: ValueKey('sheet-subtitle:$id'),
          ),
          if (row.reviewPoints > 0 || row.minorReasons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (row.reviewPoints > 0) _ReviewBadge(row: row),
                for (final reason in row.minorReasons)
                  _MinorBadge(id: id, reason: reason),
              ],
            ),
          ],
        ],
      ),
      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
    );
  }
}

/// Le badge « n points à valider » d'une ligne : il ne compte que les motifs
/// majeurs, détaillés dans l'infobulle et dans la sémantique (le survol n'est
/// jamais la seule voie). Les propositions mineures ont leur propre badge.
class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({required this.row});

  final SheetRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final heading = l10n.catalogueReviewPoints(row.reviewPoints);
    final message = [
      heading,
      for (final reason in row.reviewReasons) reviewReasonLabel(l10n, reason),
    ].join('\n');
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: message.replaceAll('\n', '. '),
      child: Tooltip(
        message: message,
        excludeFromSemantics: true,
        child: StatusBadge(
          key: ValueKey('review-badge:${row.id.value}'),
          tone: BadgeTone.attention,
          label: heading,
        ),
      ),
    );
  }
}

/// Badge neutre d'une proposition mineure (théorie, règle de lien) : signalée
/// là où elle l'était avant U8, jamais comptée dans les points à valider.
class _MinorBadge extends StatelessWidget {
  const _MinorBadge({required this.id, required this.reason});

  final String id;
  final ReviewReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = reviewReasonLabel(l10n, reason);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: l10n.catalogueMinorSemantics(label),
      child: Tooltip(
        message: l10n.catalogueMinorHint,
        excludeFromSemantics: true,
        child: StatusBadge(
          key: ValueKey('review:$id:${reason.name}'),
          tone: BadgeTone.neutral,
          label: label,
        ),
      ),
    );
  }
}
