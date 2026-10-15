import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// État d'un élève sur l'exercice en cours : le sens est porté par l'icône et
/// le libellé, jamais par la couleur seule.
enum StudentChipStatus { todo, missed, reached }

/// Prénom d'un élève et pastille d'état (à faire, manqué, réussi), R4.
///
/// Composant sans dépendance aux entités : le parent fournit le prénom, le
/// libellé d'état et, au besoin, un détail court (« 2/5 »). Hauteur d'au
/// moins 48 dp ; le prénom passe sur deux lignes au plus ; l'état « réussi »
/// prend le bleu-tapis (`secondary`, ADR 0010), aucun rouge d'état.
class StudentChip extends StatelessWidget {
  const StudentChip({
    required this.name,
    required this.status,
    required this.statusLabel,
    this.detail,
    this.semanticsLabel,
    this.maxWidth,
    this.nameMaxLines = 2,
    super.key,
  });

  final String name;
  final StudentChipStatus status;

  /// Libellé de l'état, porté par l'infobulle et la sémantique par défaut.
  final String statusLabel;

  /// Texte court sous le prénom (cumul « 2/5 », par exemple).
  final String? detail;

  /// Annonce complète ; par défaut « prénom, état ».
  final String? semanticsLabel;

  /// Largeur maximale ; `null` : celle du contenu.
  final double? maxWidth;

  /// Lignes du prénom avant l'ellipse (1 pour une liste dense).
  final int nameMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color) = switch (status) {
      StudentChipStatus.todo => (
        Icons.radio_button_unchecked,
        scheme.onSurfaceVariant,
      ),
      StudentChipStatus.missed => (
        Icons.remove_circle_outline,
        scheme.onSurfaceVariant,
      ),
      StudentChipStatus.reached => (
        Icons.check_circle_outline,
        scheme.secondary,
      ),
    };
    return Semantics(
      container: true,
      label: semanticsLabel ?? '$name, $statusLabel',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
            maxWidth: maxWidth ?? double.infinity,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: nameMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                    if (detail != null)
                      Text(detail!, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
