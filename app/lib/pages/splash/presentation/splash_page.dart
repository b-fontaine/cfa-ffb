import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Écran de démarrage, tant que la session n'est pas connue : le service
/// d'authentification s'initialise et la session persistée est lue.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: l10n.splashLoading,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Text(
                    l10n.appTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const ExcludeSemantics(child: CircularProgressIndicator()),
                const SizedBox(height: AppSpacing.md),
                ExcludeSemantics(child: Text(l10n.splashLoading)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
