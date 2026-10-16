part of 'run_sheet_view.dart';

/// Feuille « La séance » (menu ⋮) : titre, public et durée, thème ludique et
/// notion, et le nombre de propositions `[Prop]` de l'étape. Ce qui a quitté
/// l'en-tête compact reste à un geste ; la provenance y est toujours affichée.
Future<void> _showSessionInfo(
  BuildContext context,
  RunPlan plan,
  RunStep step,
) {
  final l10n = AppLocalizations.of(context);
  final sheet = plan.sheet;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            key: const ValueKey('session-info'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.guideSessionInfo,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.sheetFullTitle(sheet.title, sheet.part, plan.partCount),
                style: theme.textTheme.titleMedium,
              ),
              Text(
                l10n.sheetAudienceOption(
                  plan.audience.label(l10n),
                  plan.audience.sessionDuration.inMinutes,
                ),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.sheetTheme(sheet.theme.name),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const ProvenanceBadge(provenance: Provenance.prop),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.sheetNotion(sheet.notion),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.guideSessionInfoProposals(plan.proposalCountOf(step)),
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    },
  );
}
