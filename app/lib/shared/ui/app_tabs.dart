import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Onglets de premier niveau d'une destination (par exemple « Séances ») :
/// une rangée de libellés, l'onglet courant souligné.
///
/// Chaque onglet est un bouton d'au moins 48 dp, annoncé « sélectionné » aux
/// lecteurs d'écran ; le contenu qu'il commande est affiché par l'appelant.
class AppTabs extends StatelessWidget {
  const AppTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.semanticLabel,
    super.key,
  }) : assert(labels.length >= 2, 'at least two tabs');

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Nom du groupe d'onglets pour les lecteurs d'écran.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _Tab(
                label: labels[i],
                selected: i == selectedIndex,
                color: theme.colorScheme.primary,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? color : theme.colorScheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: selected ? color : theme.colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
