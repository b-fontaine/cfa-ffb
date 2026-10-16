import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Une action du menu ⋮ de [StepAppBar] : libellé et rappel injectés.
///
/// [checked] fait de l'action une case à cocher (état annoncé « coché » aux
/// lecteurs d'écran) ; absent, c'est une action simple. [enabled] faux la
/// grise : elle ne peut pas être choisie.
@immutable
class StepAppBarAction {
  const StepAppBarAction({
    required this.label,
    required this.onSelected,
    this.icon,
    this.checked,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
  final bool? checked;
  final bool enabled;
}

/// En-tête compact d'une étape : bouton retour ou fermer optionnel, titre de
/// l'étape (en-tête sémantique, tronqué si long), position « 6/9 » et menu ⋮
/// des [actions] injectées (absent si la liste est vide).
///
/// Hauteur fixe de 48 dp (≤ 56). Aucune logique de guide : le parent fournit
/// libellés et rappels. [onBack] prime sur [onClose] si les deux sont donnés.
class StepAppBar extends StatelessWidget implements PreferredSizeWidget {
  const StepAppBar({
    required this.title,
    required this.position,
    required this.total,
    this.actions = const [],
    this.onBack,
    this.onClose,
    super.key,
  }) : assert(total > 0, 'total must be positive'),
       assert(position >= 1 && position <= total, 'position out of range');

  final String title;
  final int position;
  final int total;
  final List<StepAppBarAction> actions;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Size get preferredSize => const Size.fromHeight(AppSpacing.minTouchTarget);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final leadingTap = onBack ?? onClose;
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppSpacing.minTouchTarget,
          child: Row(
            children: [
              if (leadingTap != null)
                IconButton(
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.minTouchTarget,
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                  tooltip: onBack != null
                      ? l10n.commonBack
                      : l10n.stepAppBarClose,
                  onPressed: leadingTap,
                  icon: Icon(onBack != null ? Icons.arrow_back : Icons.close),
                )
              else
                const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              Semantics(
                label: l10n.stepAppBarPosition(position, total),
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    '$position/$total',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
              if (actions.isNotEmpty)
                PopupMenuButton<int>(
                  key: const ValueKey('step-app-bar-menu'),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(AppSpacing.minTouchTarget),
                  ),
                  tooltip: l10n.stepAppBarMenu,
                  onSelected: (index) => actions[index].onSelected(),
                  itemBuilder: (context) => [
                    for (var i = 0; i < actions.length; i++)
                      if (actions[i].checked case final checked?)
                        CheckedPopupMenuItem<int>(
                          value: i,
                          checked: checked,
                          enabled: actions[i].enabled,
                          child: Text(actions[i].label),
                        )
                      else
                        PopupMenuItem<int>(
                          value: i,
                          enabled: actions[i].enabled,
                          child: Row(
                            children: [
                              if (actions[i].icon != null) ...[
                                Icon(actions[i].icon),
                                const SizedBox(width: AppSpacing.sm),
                              ],
                              Flexible(child: Text(actions[i].label)),
                            ],
                          ),
                        ),
                  ],
                )
              else
                const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
