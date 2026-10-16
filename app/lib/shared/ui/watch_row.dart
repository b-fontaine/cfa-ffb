import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';

/// Ligne « élève à surveiller » : prénom, détail (exercice, échecs) et niveau
/// d'alerte écrit en toutes lettres (jamais la couleur seule, pas de rouge
/// d'état : ADR 0010). Au moins 48 dp de haut ; tape si [onTap] est donné.
class WatchRow extends StatelessWidget {
  const WatchRow({
    required this.name,
    required this.detail,
    required this.persistent,
    this.onTap,
    super.key,
  });

  final String name;
  final String detail;

  /// Alerte persistante (« Action nécessaire ») plutôt que d'attention.
  final bool persistent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final status = theme.extension<StatusColors>() ?? StatusColors.light;
    final level = persistent ? l10n.alertPersistent : l10n.alertAttention;
    return Semantics(
      container: true,
      button: onTap != null,
      label: l10n.watchRowLabel(name, detail, level),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mediumRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleSmall),
                      Text(detail, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: status.attention,
                    borderRadius: AppRadii.mediumRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          persistent
                              ? Icons.priority_high
                              : Icons.warning_amber_rounded,
                          size: 18,
                          color: status.onAttention,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          level,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: status.onAttention,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
