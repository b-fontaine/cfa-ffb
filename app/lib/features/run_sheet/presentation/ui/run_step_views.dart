part of 'run_sheet_view.dart';

/// Cible tactile minimale des boutons d'icône (48 dp).
const BoxConstraints _touchTarget = BoxConstraints(
  minWidth: AppSpacing.minTouchTarget,
  minHeight: AppSpacing.minTouchTarget,
);

/// Marque un élément par sa provenance ; la clé `source:<élément>` permet de
/// retrouver le badge d'un élément précis.
class _Source extends StatelessWidget {
  const _Source({required this.element, required this.provenance});

  final String element;
  final Provenance provenance;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey('source:$element'),
    child: ProvenanceBadge(provenance: provenance),
  );
}

/// Texte courant d'une étape.
class _Line extends StatelessWidget {
  const _Line(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(text, style: style ?? Theme.of(context).textTheme.bodyLarge),
  );
}

/// Liste à puces : le texte seul porte le sens.
class _Bullets extends StatelessWidget {
  const _Bullets(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Text('•  ', style: style)),
                Expanded(child: Text(item, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ligne `[Prop]` : le badge « Proposition » précède le texte.
class _ProposalLine extends StatelessWidget {
  const _ProposalLine({required this.element, required this.text, this.detail});

  final String element;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Source(element: element, provenance: Provenance.prop),
          const SizedBox(height: AppSpacing.xs),
          _Line(text),
          if (detail != null) _Line(detail),
        ],
      ),
    );
  }
}

/// Mise en page d'une étape : en-tête, puis texte et média (côte à côte sur
/// tablette en paysage, l'un sous l'autre sur téléphone).
class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.title,
    required this.text,
    this.minutes,
    this.badges = const [],
    this.media = const [],
    this.lead = const [],
  });

  final String title;
  final int? minutes;
  final List<Widget> badges;

  /// Lignes sous l'en-tête, sur toute la largeur.
  final List<Widget> lead;
  final List<Widget> text;
  final List<Widget> media;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final header = [
      Semantics(
        header: true,
        child: Text(title, style: theme.textTheme.titleLarge),
      ),
      const SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (minutes != null)
            Text(
              l10n.sessionDurationMinutes(minutes!),
              style: theme.textTheme.labelLarge,
            ),
          ...badges,
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      ...lead,
    ];
    return Card(
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= _wideStepWidth && media.isNotEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...header,
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: text,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: media,
                        ),
                      ),
                    ],
                  )
                else ...[
                  ...media,
                  ...text,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.plan,
    required this.step,
    required this.state,
    required this.specs,
    required this.onRecord,
  });

  final RunPlan plan;
  final RunStep step;
  final RunSheetState state;
  final Map<String, ui.TableDiagramSpec> specs;
  final ValueChanged<ExerciseRef> onRecord;

  @override
  Widget build(BuildContext context) {
    switch (step.kind) {
      case RunStepKind.recall:
        return _RecallStep(plan: plan, step: step, specs: specs);
      case RunStepKind.theory:
        final section = plan.theoryOf(step);
        return section == null
            ? const SizedBox.shrink()
            : _TheoryStep(
                plan: plan,
                step: step,
                section: section,
                specs: specs,
              );
      case RunStepKind.initiation:
        final item = plan.initiationOf(step);
        return item == null
            ? const SizedBox.shrink()
            : _InitiationStep(
                plan: plan,
                step: step,
                item: item,
                state: state,
                specs: specs,
              );
      case RunStepKind.exercise:
      case RunStepKind.recallExercise:
        final exercise = plan.exerciseOf(step);
        return exercise == null
            ? const SizedBox.shrink()
            : _ExerciseStep(
                plan: plan,
                step: step,
                exercise: exercise,
                specs: specs,
                onRecord: onRecord,
              );
      case RunStepKind.game:
        return _GameStep(plan: plan, step: step, state: state, specs: specs);
      case RunStepKind.review:
        return _ReviewStep(plan: plan, step: step, state: state);
    }
  }
}

List<Widget> _illustrations(
  RunPlan plan,
  RunStep step,
  Map<String, ui.TableDiagramSpec> specs,
) => [
  for (final illustration in plan.illustrationsOf(step))
    Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SheetIllustrationView(
        illustration: illustration,
        diagrams: specs,
        proposal: plan.isProposal(step),
      ),
    ),
];

class _RecallStep extends StatelessWidget {
  const _RecallStep({
    required this.plan,
    required this.step,
    required this.specs,
  });

  final RunPlan plan;
  final RunStep step;
  final Map<String, ui.TableDiagramSpec> specs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recall = plan.sheet.recall;
    final previous = plan.previous;
    return _StepLayout(
      title: previous == null
          ? l10n.sheetFirstSession
          : l10n.sheetPrevious(
              l10n.sheetFullTitle(
                previous.title,
                previous.part,
                plan.previousPartCount ?? previous.part,
              ),
            ),
      badges: [_Source(element: 'recall', provenance: recall.src)],
      text: [
        _Bullets(recall.points),
        _Line(l10n.sheetFlashQuestion(recall.ask)),
        _Line(l10n.sheetFlashAnswer(recall.answer)),
      ],
      media: _illustrations(plan, step, specs),
    );
  }
}

class _TheoryStep extends StatelessWidget {
  const _TheoryStep({
    required this.plan,
    required this.step,
    required this.section,
    required this.specs,
  });

  final RunPlan plan;
  final RunStep step;
  final SheetTheorySection section;
  final Map<String, ui.TableDiagramSpec> specs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final demo = section.demo;
    return _StepLayout(
      title: section.title,
      minutes: step.minutes,
      badges: [
        _Source(element: 'theory:${section.id}', provenance: section.src),
      ],
      text: [
        for (final paragraph in section.body) _Line(paragraph),
        if (plan.audience == Audience.adults)
          for (final extra in section.adultExtra)
            _Line(l10n.sheetAdultExtra(extra)),
        _Line(
          l10n.sheetKeyPoint(section.keyPoint),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (demo != null) _Line(l10n.sheetDemo(demo)),
      ],
      media: _illustrations(plan, step, specs),
    );
  }
}

class _InitiationStep extends StatelessWidget {
  const _InitiationStep({
    required this.plan,
    required this.step,
    required this.item,
    required this.state,
    required this.specs,
  });

  final RunPlan plan;
  final RunStep step;
  final SheetInitiation item;
  final RunSheetState state;
  final Map<String, ui.TableDiagramSpec> specs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepLayout(
      title: item.title,
      minutes: step.minutes,
      badges: [
        Text(
          l10n.sheetInitiationNumber(item.initiationSheet),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        _Source(element: 'initiation:${item.id}', provenance: item.src),
      ],
      text: [
        _Line(l10n.sheetSetup(item.setup)),
        _Line(l10n.sheetGoal(item.goal)),
        _Line(l10n.sheetExpected(item.expected)),
        const SizedBox(height: AppSpacing.sm),
        switch (item.scoring) {
          final CounterScoring counter => _CounterRow(
            initiationId: item.id,
            total: counter.of,
            count: state.counts[item.id] ?? 0,
          ),
          final ChecklistScoring checklist => _Checklist(
            initiationId: item.id,
            criteria: checklist.criteria,
            checked: state.checked[item.id] ?? const <int>{},
          ),
        },
        _Line(l10n.sheetNotRecorded),
      ],
      media: _illustrations(plan, step, specs),
    );
  }
}

/// « 3 sur 5 réussites » avec ajout et retrait (compteur local).
class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.initiationId,
    required this.total,
    required this.count,
  });

  final String initiationId;
  final int total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<RunSheetCubit>();
    return Row(
      children: [
        IconButton.outlined(
          constraints: _touchTarget,
          tooltip: l10n.guideCountRemove,
          onPressed: count == 0
              ? null
              : () => cubit.countChanged(initiationId, -1),
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              l10n.guideCount(count, total),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        IconButton.outlined(
          constraints: _touchTarget,
          tooltip: l10n.guideCountAdd,
          onPressed: count >= total
              ? null
              : () => cubit.countChanged(initiationId, 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// Grille « acquis / à retravailler » (cases locales).
class _Checklist extends StatelessWidget {
  const _Checklist({
    required this.initiationId,
    required this.criteria,
    required this.checked,
  });

  final String initiationId;
  final List<String> criteria;
  final Set<int> checked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<RunSheetCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.guideChecklistTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final (index, criterion) in criteria.indexed)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: checked.contains(index),
            title: Text(criterion),
            onChanged: (_) => cubit.criterionToggled(initiationId, index),
          ),
        Text(
          l10n.guideChecklistCount(checked.length, criteria.length),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}

class _ExerciseStep extends StatelessWidget {
  const _ExerciseStep({
    required this.plan,
    required this.step,
    required this.exercise,
    required this.specs,
    required this.onRecord,
  });

  final RunPlan plan;
  final RunStep step;
  final SheetExercise exercise;
  final Map<String, ui.TableDiagramSpec> specs;
  final ValueChanged<ExerciseRef> onRecord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spec = plan.specOf(step);
    final diagram = specs[exercise.diagramId];
    final recall = step.kind == RunStepKind.recallExercise
        ? plan.recallExercise
        : null;
    final blockTitle = recall == null ? plan.blockTitle : plan.recallBlockTitle;
    return _StepLayout(
      title: recall == null
          ? l10n.sheetExerciseHeading(exercise.ref.number, exercise.title)
          : l10n.guideRecallExerciseHeading(
              exercise.ref.number,
              exercise.title,
            ),
      minutes: step.minutes,
      badges: [
        if (recall == null)
          Text(
            l10n.guideExerciseOf(
              plan.exerciseIndexOf(step) ?? 1,
              plan.exerciseCount,
            ),
            style: theme.textTheme.labelLarge,
          )
        else
          Text(l10n.sheetPhaseRecall, style: theme.textTheme.labelLarge),
        _Source(
          element: recall == null
              ? 'exercise:${exercise.id}'
              : 'recall-exercise:${exercise.ref.blockId}-'
                    '${exercise.ref.number}',
          provenance: exercise.src,
        ),
      ],
      lead: [
        if (recall != null) ...[
          _Line(
            l10n.guideRecallFrom(
              l10n.sheetFullTitle(
                recall.origin.title,
                recall.origin.part,
                plan.recallOriginPartCount ?? recall.origin.part,
              ),
            ),
            style: theme.textTheme.titleMedium,
          ),
          _Line(
            recall.students == 0
                ? l10n.guideRecallNoStudents
                : l10n.guideRecallPending(recall.pending, recall.students),
          ),
        ],
        if (spec != null) ...[
          _Line(
            l10n.sheetRequired(spec.rate.successes, spec.rate.attempts),
            style: theme.textTheme.titleMedium,
          ),
          _Line(l10n.guidePassesToValidate(plan.passesRequired)),
          if (spec.bridge != null)
            _Line(
              spec.bridge == Bridge.frame
                  ? l10n.exerciseBridgeFrame
                  : l10n.exerciseBridgeSurface,
            ),
          if (spec.bronze) _Line(l10n.exerciseBronze),
        ],
        if (exercise.src.isProposal) _Line(l10n.sheetRateProposal),
        _Line(l10n.sheetPassesPlanned(exercise.passes)),
      ],
      media: [
        if (diagram != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: SheetIllustrationView.maxWidth,
                ),
                child: TableDiagramPlayer(
                  spec: diagram,
                  semanticLabel: l10n.exerciseDiagramSemantics(
                    exercise.ref.number,
                    blockTitle ?? plan.sheet.title,
                  ),
                ),
              ),
            ),
          )
        else
          _Line(
            plan.diagramsUnreadable
                ? l10n.diagramInvalid
                : l10n.exerciseDiagramMissing,
          ),
      ],
      text: [
        _Line(l10n.sheetSetup(exercise.setup)),
        _Line(l10n.sheetGoal(exercise.instruction)),
        _Line(l10n.sheetExpected(exercise.expected)),
        if (exercise.mistakes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.sheetMistakes, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          _Bullets([
            for (final m in exercise.mistakes)
              l10n.sheetMistakeRow(m.symptom, m.fix),
          ]),
        ],
        const SizedBox(height: AppSpacing.xs),
        _Source(element: 'playful:${exercise.id}', provenance: Provenance.prop),
        const SizedBox(height: AppSpacing.xs),
        _Line(l10n.sheetPlayfulHook(exercise.playful.hook)),
        _Line(l10n.sheetPlayfulChallenge(exercise.playful.challenge)),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () => onRecord(exercise.ref),
          icon: const Icon(Icons.edit_note_outlined),
          label: Text(l10n.guideRecord),
        ),
        if (blockTitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _Line(l10n.guideRecordHint(blockTitle)),
        ],
      ],
    );
  }
}

class _GameStep extends StatelessWidget {
  const _GameStep({
    required this.plan,
    required this.step,
    required this.state,
    required this.specs,
  });

  final RunPlan plan;
  final RunStep step;
  final RunSheetState state;
  final Map<String, ui.TableDiagramSpec> specs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final game = plan.sheet.game;
    final link = game.link;
    final adaptation = plan.audience == Audience.children
        ? game.adaptation.children
        : game.adaptation.adults;
    final materials = game.materials;
    return _StepLayout(
      title: game.title,
      minutes: step.minutes,
      badges: [_Source(element: 'game', provenance: game.src)],
      lead: [
        _Line(switch ((game.adapted, game.sourceGame)) {
          (true, final int n) => l10n.sheetGameAdapted(n),
          (false, final int n) => l10n.sheetGameSource(n),
          (_, null) => l10n.sheetGameNoSource,
        }),
      ],
      media: _illustrations(plan, step, specs),
      text: [
        _Line(l10n.sheetGamePlayers(game.players)),
        if (materials != null) _Line(l10n.sheetGameMaterials(materials)),
        Text(l10n.sheetGameRules, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        _Bullets(game.rules),
        _Line(l10n.sheetGameScoring(game.scoring)),
        _Line(l10n.sheetGameEnd(game.end)),
        _ProposalLine(
          element: 'variant',
          text: l10n.sheetGameVariant(game.playfulVariant),
        ),
        if (link != null)
          _ProposalLine(
            element: 'link',
            text: l10n.sheetGameLink(
              plan.previous?.title ?? link.notionOf.value,
              link.rule,
            ),
            detail: l10n.sheetGameLinkNote(link.note),
          ),
        if (adaptation != null)
          _ProposalLine(
            element: 'adaptation',
            text: l10n.sheetGameAdaptation(adaptation),
          ),
        const SizedBox(height: AppSpacing.md),
        _ScoreBoard(scoreA: state.scoreA, scoreB: state.scoreB),
      ],
    );
  }
}

/// Score du jeu à deux colonnes, saisi à la main (local, non enregistré).
class _ScoreBoard extends StatelessWidget {
  const _ScoreBoard({required this.scoreA, required this.scoreB});

  final int scoreA;
  final int scoreB;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<RunSheetCubit>();
    Widget column(ScoreSide side, String name, int points) => Expanded(
      child: Column(
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          Semantics(
            liveRegion: true,
            label: l10n.guideScoreValue(name, points),
            excludeSemantics: true,
            child: Text('$points', style: theme.textTheme.headlineMedium),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                constraints: _touchTarget,
                tooltip: l10n.guideScoreRemove(name),
                onPressed: points == 0
                    ? null
                    : () => cubit.scoreChanged(side, -1),
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.outlined(
                constraints: _touchTarget,
                tooltip: l10n.guideScoreAdd(name),
                onPressed: () => cubit.scoreChanged(side, 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.guideScoreTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            column(ScoreSide.a, l10n.guideScoreSideA, scoreA),
            column(ScoreSide.b, l10n.guideScoreSideB, scoreB),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _Line(l10n.guideScoreLocal),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.plan,
    required this.step,
    required this.state,
  });

  final RunPlan plan;
  final RunStep step;
  final RunSheetState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sheet = plan.sheet;
    final recap = _recap(l10n, sheet, state);
    return _StepLayout(
      title: l10n.suggestPhaseReview,
      minutes: step.minutes,
      text: [
        _Bullets([
          for (final prompt in sheet.reviewPrompts)
            l10n.sheetReviewPrompt(prompt),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.guideRecapTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        if (recap.isEmpty) _Line(l10n.guideRecapNothing) else _Bullets(recap),
        _Line(l10n.sheetNotRecorded),
        _Line(l10n.guideRecapPasses),
        if (sheet.uncertainties.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.sheetUncertainties, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          _Bullets(sheet.uncertainties),
        ],
      ],
    );
  }

  /// Ce qui a été compté sur cet écran (initiations et score du jeu).
  List<String> _recap(
    AppLocalizations l10n,
    SessionSheet sheet,
    RunSheetState state,
  ) => [
    for (final item in sheet.initiation)
      if (item.weight.isShownFor(plan.audience))
        switch (item.scoring) {
          CounterScoring(:final of) when (state.counts[item.id] ?? 0) > 0 =>
            l10n.guideRecapInitiation(item.title, state.counts[item.id]!, of),
          ChecklistScoring(:final criteria)
              when (state.checked[item.id] ?? const <int>{}).isNotEmpty =>
            l10n.guideRecapChecklist(
              item.title,
              state.checked[item.id]!.length,
              criteria.length,
            ),
          _ => null,
        },
    if (state.scoreA > 0 || state.scoreB > 0)
      l10n.guideRecapGame(state.scoreA, state.scoreB),
  ].whereType<String>().toList();
}
