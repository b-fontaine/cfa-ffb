import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Affichage agrandi pour montrer une illustration aux élèves.
///
/// Agrandit le texte de son contenu (facteur [scale], appliqué en plus du
/// réglage système), le centre sur un fond uni et écrit la [caption] en gros
/// dessous. Le contenu peut savoir qu'il est montré aux élèves avec
/// [PresentationScope.isActive].
class PresentationScope extends StatelessWidget {
  const PresentationScope({
    required this.child,
    this.caption,
    this.scale = 1.5,
    super.key,
  }) : assert(scale >= 1, 'scale doit valoir au moins 1');

  final Widget child;

  /// Légende affichée aux élèves, en gros, sous l'illustration.
  final String? caption;

  /// Facteur d'agrandissement du texte.
  final double scale;

  /// Vrai quand [context] est sous un [PresentationScope].
  static bool isActive(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_PresentationMarker>() != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context);
    final text = caption;
    return Semantics(
      label: l10n.presentationScopeLabel,
      container: true,
      child: _PresentationMarker(
        child: MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(media.textScaler.scale(1) * scale),
          ),
          child: ColoredBox(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: child),
                  if (text != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PresentationMarker extends InheritedWidget {
  const _PresentationMarker({required super.child});

  @override
  bool updateShouldNotify(_PresentationMarker oldWidget) => false;
}
