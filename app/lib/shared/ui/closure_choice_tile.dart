import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Une ligne de l'assistant de clôture : le prénom, le motif de la
/// proposition et un interrupteur « Effacer » (allumé) / « Reconduire »
/// (éteint). Le nom accessible dit le prénom et le choix courant ; la cible
/// fait au moins 48 dp. L'effacement est montré par l'icône et le mot, jamais
/// par la couleur seule.
class ClosureChoiceTile extends StatelessWidget {
  const ClosureChoiceTile({
    required this.name,
    required this.reason,
    required this.erase,
    required this.onChanged,
    super.key,
  });

  final String name;

  /// Motif de la proposition, en clair (« Absent de toutes les séances… »).
  final String reason;

  /// Vrai quand l'élève sera effacé.
  final bool erase;

  /// Reçoit vrai pour « Effacer », faux pour « Reconduire ».
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final choice = erase ? l10n.closureChoiceErase : l10n.closureChoiceKeep;
    return Semantics(
      container: true,
      label: l10n.closureTileLabel(name, choice),
      toggled: erase,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onChanged(!erase),
          borderRadius: AppRadii.smallRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget + AppSpacing.md,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          reason,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    erase ? Icons.delete_outline : Icons.check_circle_outline,
                    color: erase
                        ? theme.colorScheme.error
                        : theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 84,
                    child: Text(choice, style: theme.textTheme.labelLarge),
                  ),
                  Switch(value: erase, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
