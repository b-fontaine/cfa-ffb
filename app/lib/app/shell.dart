import 'package:billard_cfa/app/router.dart';
import 'package:billard_cfa/features/app_update/presentation/bloc/app_update_cubit.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_navigation.dart';
import 'package:billard_cfa/shared/ui/app_tabs.dart';
import 'package:billard_cfa/shared/ui/app_update_banner.dart';
import 'package:billard_cfa/shared/ui/nav_icon.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Cadre de navigation principale : barre (smartphone) ou rail (tablette,
/// desktop, web), la destination étant déduite de l'adresse courante. Les trois
/// écrans de « Séances » (Planifiées, Catalogue, Suggestion) sont surmontés de
/// leurs onglets.
class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static int indexOf(String location) {
    if (location.startsWith(AppRoutes.students)) return 1;
    if (location.startsWith(AppRoutes.record)) return 2;
    if (location.startsWith(AppRoutes.catalogue) ||
        location.startsWith(AppRoutes.planner) ||
        location.startsWith(AppRoutes.session) ||
        location.startsWith(AppRoutes.exercises)) {
      return 3;
    }
    if (location.startsWith(AppRoutes.more) ||
        location.startsWith(AppRoutes.backup) ||
        location.startsWith(AppRoutes.settings)) {
      return 4;
    }
    return 0;
  }

  /// Onglet de la destination « Séances » pour [location] : un des trois
  /// écrans à onglets (Planifiées, Catalogue, Suggestion), `null` ailleurs
  /// (les pages ouvertes depuis un onglet n'affichent pas les onglets).
  static int? sessionsTabOf(String location) {
    final path = location.length > 1 && location.endsWith('/')
        ? location.substring(0, location.length - 1)
        : location;
    final index = _sessionsTabPaths.indexOf(path);
    return index < 0 ? null : index;
  }

  static const List<String> _sessionsTabPaths = [
    AppRoutes.planner,
    AppRoutes.catalogue,
    AppRoutes.session,
  ];

  static const List<String> _paths = [
    AppRoutes.home,
    AppRoutes.students,
    AppRoutes.record,
    AppRoutes.catalogue,
    AppRoutes.more,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tab = sessionsTabOf(location);
    return AppNavigation(
      destinations: [
        AppDestination(
          icon: const NavIcon(NavGlyph.today),
          selectedIcon: const NavIcon(NavGlyph.today, selected: true),
          label: l10n.navHome,
        ),
        AppDestination(
          icon: const NavIcon(NavGlyph.students),
          selectedIcon: const NavIcon(NavGlyph.students, selected: true),
          label: l10n.navStudents,
        ),
        AppDestination(
          icon: const NavIcon(NavGlyph.results),
          selectedIcon: const NavIcon(NavGlyph.results, selected: true),
          label: l10n.navResults,
        ),
        AppDestination(
          icon: const NavIcon(NavGlyph.sessions),
          selectedIcon: const NavIcon(NavGlyph.sessions, selected: true),
          label: l10n.navSessions,
        ),
        AppDestination(
          icon: const NavIcon(NavGlyph.more),
          selectedIcon: const NavIcon(NavGlyph.more, selected: true),
          label: l10n.navMore,
        ),
      ],
      selectedIndex: indexOf(location),
      onSelected: (index) => context.go(_paths[index]),
      body: _UpdateAwareBody(
        child: Column(
          children: [
            // Emplacement stable : le contenu ne se reconstruit pas quand les
            // onglets apparaissent ou disparaissent.
            if (tab == null)
              const SizedBox.shrink()
            else
              SafeArea(
                bottom: false,
                child: ResponsiveBody(
                  child: AppTabs(
                    semanticLabel: l10n.sessionsTabsLabel,
                    labels: [
                      l10n.sessionsTabPlanned,
                      l10n.sessionsTabCatalogue,
                      l10n.sessionsTabSuggestion,
                    ],
                    selectedIndex: tab,
                    onSelected: (index) => context.go(_sessionsTabPaths[index]),
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Le contenu de la destination, surmonté de la bannière « nouvelle version »
/// quand une version attend. Le contenu garde sa place dans l'arbre que la
/// bannière soit là ou non : afficher ou masquer la bannière ne reconstruit
/// pas l'écran (la saisie en cours est conservée).
class _UpdateAwareBody extends StatelessWidget {
  const _UpdateAwareBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AppUpdateCubit>();
    return BlocBuilder<AppUpdateCubit, AppUpdateState>(
      builder: (context, state) => Column(
        children: [
          if (state.visible)
            SafeArea(
              bottom: false,
              child: AppUpdateBanner(
                onUpdate: cubit.apply,
                onLater: cubit.dismiss,
              ),
            ),
          Expanded(
            // La bannière absorbe l'encoche : l'écran dessous ne la
            // réserve plus.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: state.visible,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
