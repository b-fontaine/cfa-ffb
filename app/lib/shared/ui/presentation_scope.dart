import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Affichage agrandi pour montrer une illustration aux élèves.
///
/// Agrandit le texte de son contenu (facteur [scale], appliqué en plus du
/// réglage système), le centre sur un fond uni et écrit la [caption] en gros
/// dessous. Le contenu peut savoir qu'il est montré aux élèves avec
/// [PresentationScope.isActive].
///
/// Avec [transparent], le fond n'est pas peint (un motif passe derrière) et la
/// légende est posée sur un [PresentationCaption] : son contraste ne dépend
/// jamais du motif.
class PresentationScope extends StatelessWidget {
  const PresentationScope({
    required this.child,
    this.caption,
    this.scale = 1.5,
    this.transparent = false,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  }) : assert(scale >= 1, 'scale doit valoir au moins 1');

  final Widget child;

  /// Légende affichée aux élèves, en gros, sous l'illustration.
  final String? caption;

  /// Facteur d'agrandissement du texte.
  final double scale;

  /// Vrai : pas de fond peint, la légende est posée sur un panneau.
  final bool transparent;

  /// Marge autour du contenu et de la légende.
  final EdgeInsetsGeometry padding;

  /// Vrai quand [context] est sous un [PresentationScope].
  static bool isActive(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_PresentationMarker>() != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context);
    final text = caption;
    final content = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: child),
          if (text != null) ...[
            const SizedBox(height: AppSpacing.md),
            if (transparent)
              PresentationCaption(text: text)
            else
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
          ],
        ],
      ),
    );
    return Semantics(
      label: l10n.presentationScopeLabel,
      container: true,
      child: _PresentationMarker(
        child: MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(media.textScaler.scale(1) * scale),
          ),
          child: transparent
              ? content
              : ColoredBox(color: theme.colorScheme.surface, child: content),
        ),
      ),
    );
  }
}

/// Légende d'une illustration montrée aux élèves, posée sur un panneau
/// `surface` arrondi : le texte ne dépend jamais du motif de tapis derrière.
class PresentationCaption extends StatelessWidget {
  const PresentationCaption({
    required this.text,
    this.style,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    super.key,
  });

  final String text;

  /// Marge entre le bord du panneau et le texte.
  final EdgeInsetsGeometry padding;

  /// Style du texte ; `headlineSmall` par défaut.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadii.mediumRadius,
      child: Padding(
        padding: padding,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: (style ?? theme.textTheme.headlineSmall)?.copyWith(
            color: theme.colorScheme.onSurface,
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
