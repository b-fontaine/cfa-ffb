import 'package:billard_cfa/app/router.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Cadre de navigation principale : barre (smartphone) ou rail (tablette,
/// desktop, web), l'onglet étant déduit de l'adresse courante.
class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static int indexOf(String location) {
    if (location.startsWith(AppRoutes.students)) return 1;
    if (location.startsWith(AppRoutes.record)) return 2;
    if (location.startsWith(AppRoutes.session) ||
        location.startsWith(AppRoutes.exercises)) {
      return 3;
    }
    if (location.startsWith(AppRoutes.backup)) return 4;
    return 0;
  }

  static const List<String> _paths = [
    AppRoutes.home,
    AppRoutes.students,
    AppRoutes.record,
    AppRoutes.session,
    AppRoutes.backup,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppNavigation(
      destinations: [
        AppDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: l10n.navHome,
        ),
        AppDestination(
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups,
          label: l10n.navStudents,
        ),
        AppDestination(
          icon: Icons.edit_note_outlined,
          selectedIcon: Icons.edit_note,
          label: l10n.navResults,
        ),
        AppDestination(
          icon: Icons.event_note_outlined,
          selectedIcon: Icons.event_note,
          label: l10n.navSession,
        ),
        AppDestination(
          icon: Icons.save_alt_outlined,
          selectedIcon: Icons.save_alt,
          label: l10n.navBackup,
        ),
      ],
      selectedIndex: indexOf(location),
      onSelected: (index) => context.go(_paths[index]),
      body: child,
    );
  }
}
