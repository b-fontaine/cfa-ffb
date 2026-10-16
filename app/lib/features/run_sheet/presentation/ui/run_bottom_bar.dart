part of 'run_sheet_view.dart';

/// Barre basse : « Précédent », « Noter les résultats » (exercices et créneau
/// de rappel) et « Suivant » ; « Terminer » remplace « Suivant » à la dernière
/// étape. Cibles d'au moins 48 dp.
///
/// À partir de 600 dp, trois boutons avec leur texte. En dessous, des flèches
/// (infobulle et nom accessible « Précédent » / « Suivant ») de part et
/// d'autre d'un bouton plein « Noter les résultats » ; sans saisie, deux
/// boutons avec texte. À texte agrandi (≥ 130 %), les boutons s'empilent à
/// pleine largeur.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.stepCount,
    required this.onStep,
    required this.onRecord,
    required this.onFinish,
  });

  final int step;
  final int stepCount;
  final ValueChanged<int> onStep;

  /// Ouvre la saisie des résultats ; `null` hors exercice.
  final VoidCallback? onRecord;

  /// Demande de terminer la séance (la confirmation est faite par l'appelant).
  final VoidCallback onFinish;

  static const _buttonSize = Size(AppSpacing.minTouchTarget, 56);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isLast = step == stepCount - 1;
    final large = MediaQuery.textScalerOf(context).scale(1) >= _largeTextScale;
    final record = onRecord;
    final previousAction = step == 0 ? null : () => onStep(step - 1);
    final nextAction = isLast ? onFinish : () => onStep(step + 1);

    final previous = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: _buttonSize),
      onPressed: previousAction,
      icon: const Icon(Icons.arrow_back),
      label: Text(l10n.guidePrevious),
    );
    final next = isLast
        ? FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: _buttonSize),
            onPressed: nextAction,
            icon: const Icon(Icons.flag_outlined),
            label: Text(l10n.guideFinishShort),
          )
        : record == null
        ? FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: _buttonSize),
            onPressed: nextAction,
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.guideNext),
          )
        : FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: _buttonSize),
            onPressed: nextAction,
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.guideNext),
          );
    final note = record == null
        ? null
        : FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: _buttonSize),
            onPressed: record,
            icon: const Icon(Icons.edit_note_outlined),
            label: Text(l10n.guideRecord),
          );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.guideBottomBarLabel,
      child: DecoratedBox(
        key: const ValueKey('guide-bottom-bar'),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < _compactWidth;
                if (compact && large) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (note != null) ...[
                        note,
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      previous,
                      const SizedBox(height: AppSpacing.sm),
                      next,
                    ],
                  );
                }
                if (compact && note != null && !isLast) {
                  return Row(
                    children: [
                      IconButton.outlined(
                        constraints: BoxConstraints.tight(_buttonSize),
                        tooltip: l10n.guidePrevious,
                        onPressed: previousAction,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: note),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filledTonal(
                        constraints: BoxConstraints.tight(_buttonSize),
                        tooltip: l10n.guideNext,
                        onPressed: nextAction,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: previous),
                    if (note != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 2, child: note),
                    ],
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: next),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
