import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/brand_colors.dart';
import 'package:flutter/material.dart';

/// Public d'une séance, côté interface (indépendant du domaine).
enum AudienceKind { children, adults }

/// Badge de public : icône + libellé, sur un conteneur propre à chaque public.
class AudienceBadge extends StatelessWidget {
  const AudienceBadge({required this.kind, super.key});

  final AudienceKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final brand =
        theme.extension<BrandColors>() ??
        (scheme.brightness == Brightness.dark
            ? BrandColors.dark
            : BrandColors.light);
    final (background, foreground, icon, label) = switch (kind) {
      AudienceKind.children => (
        brand.accentContainer,
        brand.onAccentContainer,
        Icons.child_care,
        l10n.audienceChildren,
      ),
      AudienceKind.adults => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.person,
        l10n.audienceAdults,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.smallRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 16, color: foreground)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
