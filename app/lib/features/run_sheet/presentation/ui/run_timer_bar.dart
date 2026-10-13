part of 'run_sheet_view.dart';

/// Phase courante : « Nom · N min » (minutes `[Prop]`, badge « Proposition »).
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
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const _Source(element: 'minutes', provenance: Provenance.prop),
        ],
      ),
    );
  }
}

/// Minuteur indicatif de la phase : jamais bloquant, alerte douce à moins
/// d'une minute et au dépassement.
class _TimerBar extends StatelessWidget {
  const _TimerBar({required this.plan, required this.state});

  final RunPlan plan;
  final RunSheetState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<RunSheetCubit>();
    final phase = plan.steps[state.step].phase;
    final planned = plan.timing.phaseMinutes[phase] ?? 0;
    final remaining = planned * 60 - state.timerSeconds;
    final value = l10n.guideTimerValue(runClock(state.timerSeconds), planned);
    final started = state.timerRunning || state.timerSeconds > 0;
    final alert = !started
        ? null
        : remaining < 0
        ? l10n.guideTimerOver(runClock(-remaining))
        : remaining <= 60
        ? l10n.guideTimerSoon
        : null;
    return Card(
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ExcludeSemantics(child: Icon(Icons.timer_outlined)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${l10n.guideTimerTitle} · $value',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                IconButton(
                  constraints: _touchTarget,
                  tooltip: state.timerRunning
                      ? l10n.guideTimerPause
                      : l10n.guideTimerStart,
                  onPressed: cubit.timerToggled,
                  icon: Icon(
                    state.timerRunning
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                  ),
                ),
                IconButton(
                  constraints: _touchTarget,
                  tooltip: l10n.guideTimerReset,
                  onPressed: state.timerSeconds == 0 ? null : cubit.timerReset,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
            if (alert != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      const ExcludeSemantics(
                        child: Icon(Icons.hourglass_bottom, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(alert, style: theme.textTheme.titleSmall),
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
}
