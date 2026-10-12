import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Une destination de la navigation principale.
@immutable
class AppDestination {
  const AppDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Navigation principale adaptative : barre en bas sur smartphone, rail à
/// gauche dès [wideBreakpoint] (tablette, desktop, web). Les libellés sont
/// toujours affichés (jamais l'icône seule).
class AppNavigation extends StatelessWidget {
  const AppNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    this.wideBreakpoint = 720,
    super.key,
  }) : assert(destinations.length >= 2, 'at least two destinations');

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;
  final double wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        if (wide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  Semantics(
                    container: true,
                    label: l10n.navigationLabel,
                    child: NavigationRail(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onSelected,
                      labelType: NavigationRailLabelType.all,
                      minWidth: AppSpacing.minTouchTarget + AppSpacing.lg,
                      destinations: [
                        for (final destination in destinations)
                          NavigationRailDestination(
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: Semantics(
            container: true,
            label: l10n.navigationLabel,
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
