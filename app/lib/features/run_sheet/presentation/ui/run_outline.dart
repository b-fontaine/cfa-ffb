part of 'run_sheet_view.dart';

/// Sommaire : toutes les étapes, par phase ; une sélection saute à l'étape
/// (pour relire un jeu en contexte, par exemple).
Future<void> _showOutline(
  BuildContext context,
  RunPlan plan,
  int current,
  ValueChanged<int> onStep,
) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Semantics(
              header: true,
              child: Text(
                l10n.guideOutlineTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
          ),
          // Une douzaine de lignes au plus : toutes construites, pour que la
          // dernière (le bilan) se laisse faire défiler jusqu'à elle.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, step) in plan.steps.indexed)
                    ListTile(
                      selected: index == current,
                      leading: ExcludeSemantics(child: Text('${index + 1}')),
                      title: Text(runStepTitle(l10n, plan, step)),
                      subtitle: Text(
                        l10n.guideOutlineRow(
                          runPhaseTitle(l10n, step.phase),
                          step.minutes,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onStep(index);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
