import 'package:billard_cfa/features/track_group/domain/group_grid.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Le « Résumé en texte » de la carte de chaleur : pour chaque technique, les
/// prénoms des élèves qui l'ont terminée, de ceux qui sont en cours et de
/// ceux qui doivent la commencer. Repliable, jamais caché : il se lit à voix
/// haute, s'imprime et remplace la grille pour qui ne la voit pas.
class GroupTextSummary extends StatelessWidget {
  const GroupTextSummary({required this.grid, super.key});

  final GroupGrid grid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final names = {for (final s in grid.students) s.id: s.firstName};
    String list(List<StudentId> ids) => ids.isEmpty
        ? l10n.groupSummaryNobody
        : ids.map((id) => names[id] ?? id.value).join(', ');
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.mediumRadius),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Semantics(
          header: true,
          child: Text(
            l10n.groupSummaryTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        children: [
          for (final row in grid.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                l10n.groupSummaryRow(
                  row.technique.title,
                  list(row.finished),
                  list(row.inProgress),
                  list(row.toStart),
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
