part of 'run_sheet_view.dart';

/// Nom court d'une phase pour la frise (le nom complet reste dans la ligne de
/// phase et la sémantique).
String _shortPhase(AppLocalizations l10n, SessionPhase phase) =>
    switch (phase) {
      SessionPhase.welcome => l10n.guidePhaseShortWelcome,
      SessionPhase.notionAndInitiation => l10n.guidePhaseShortNotion,
      SessionPhase.training => l10n.guidePhaseShortTraining,
      SessionPhase.game => l10n.guidePhaseShortGame,
      SessionPhase.review => l10n.guidePhaseShortReview,
    };

/// Frise des phases : la phase de l'étape courante est marquée, un tap saute à
/// la première étape de la phase.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.plan,
    required this.step,
    required this.onStep,
  });

  final RunPlan plan;
  final int step;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phases = plan.phases;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: PhaseTimeline(
        phases: [
          for (final phase in phases)
            PhaseTimelineEntry(
              label: _shortPhase(l10n, phase),
              minutes: math.max(1, plan.timing.phaseMinutes[phase] ?? 0),
            ),
        ],
        currentIndex: plan.phaseIndexOf(step),
        onSelected: (index) {
          final first = plan.firstStepOf(phases[index]);
          if (first != null) onStep(first);
        },
      ),
    );
  }
}

/// Ligne « phase · minuteur » : le nom de la phase et ses minutes à gauche, le
/// temps restant (neutre, attention, dépassé) à droite. Passe à la ligne
/// plutôt que de déborder en grand texte.
class _PhaseTimerRow extends StatelessWidget {
  const _PhaseTimerRow({required this.plan, required this.state});

  final RunPlan plan;
  final RunSheetState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RunSheetCubit>();
    final remaining = state.timerRemaining ?? Duration.zero;
    final phase = _PhaseLine(plan: plan, step: plan.steps[state.step]);
    final chip = TimerChip(
      remaining: remaining,
      running: state.timerRunning,
      onToggle: cubit.timerToggled,
    );
    final large = MediaQuery.textScalerOf(context).scale(1) >= _largeTextScale;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      // En grand texte le minuteur passe sous la phase plutôt que de lui
      // prendre la largeur.
      child: large
          ? Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: AppSpacing.xs,
              spacing: AppSpacing.sm,
              children: [phase, chip],
            )
          : Row(
              children: [
                Expanded(child: phase),
                const SizedBox(width: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: chip,
                ),
              ],
            ),
    );
  }
}

/// Phase courante : « Nom · N min » (minutes `[Prop]`, badge « Proposition »
/// en mode « Relecture »).
class _PhaseLine extends StatelessWidget {
  const _PhaseLine({required this.plan, required this.step});

  final RunPlan plan;
  final RunStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      header: true,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.suggestPhaseLine(
              runPhaseTitle(l10n, step.phase),
              plan.timing.phaseMinutes[step.phase] ?? 0,
            ),
            key: ValueKey('phase:${step.phase.name}'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const _Source(element: 'minutes', provenance: Provenance.prop),
        ],
      ),
    );
  }
}
