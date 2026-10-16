part of 'sheet_detail_view.dart';

/// Données partagées par les sections d'une séance affichée.
class _SheetScope {
  const _SheetScope({
    required this.detail,
    required this.audience,
    required this.timing,
    required this.specs,
  });

  final SheetDetail detail;
  final Audience audience;
  final SheetTiming timing;

  /// Schémas du design system par identifiant de diagramme.
  final Map<String, ui.TableDiagramSpec> specs;

  SessionSheet get sheet => detail.sheet;

  Illustration? illustration(String id) {
    for (final i in sheet.illustrations) {
      if (i.id == id) return i;
    }
    return null;
  }
}

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

/// Texte courant du détail.
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

/// Carte d'un élément : titre, minutes, provenance puis le contenu.
class _ElementCard extends StatelessWidget {
  const _ElementCard({
    required this.title,
    required this.children,
    this.minutes,
    this.badges = const [],
  });

  final String title;
  final int? minutes;
  final List<Widget> badges;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
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
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ThemeBlock extends StatelessWidget {
  const _ThemeBlock({required this.sheet});

  final SessionSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.sheetTheme(sheet.theme.name),
              style: theme.textTheme.titleMedium,
            ),
            const _Source(element: 'theme', provenance: Provenance.prop),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(sheet.theme.pitch, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.sheetNotion(sheet.notion), style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

/// La note « n points à valider » : le même compte que le badge du catalogue,
/// avec une ligne par motif (ceux qui comptent, puis les propositions
/// mineures qui ne comptent pas).
class _ToValidateNote extends StatelessWidget {
  const _ToValidateNote({required this.row});

  final SheetRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('review-note'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const ProposalBadge(),
            Text(
              l10n.catalogueReviewPoints(row.reviewPoints),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.sheetToValidateNote, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xs),
        for (final reason in [...row.reviewReasons, ...row.minorReasons])
          Padding(
            key: ValueKey('review-note:${reason.name}'),
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                const ExcludeSemantics(child: Icon(Icons.circle, size: 6)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    reviewReasonLabel(l10n, reason),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AudienceBar extends StatelessWidget {
  const _AudienceBar({
    required this.audience,
    required this.total,
    required this.onChanged,
  });

  final Audience audience;
  final int total;
  final ValueChanged<Audience> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in Audience.values)
              ChoiceChip(
                label: Text(
                  l10n.sheetAudienceOption(
                    option.label(l10n),
                    option.sessionDuration.inMinutes,
                  ),
                ),
                selected: option == audience,
                onSelected: (_) => onChanged(option),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.sheetTotalDuration(total),
              style: theme.textTheme.bodyLarge,
            ),
            const _Source(element: 'minutes', provenance: Provenance.prop),
          ],
        ),
      ],
    );
  }
}

/// Libellé court d'une phase dans la frise (« Accueil » en première séance,
/// « Rappel » ensuite).
String _timelineLabel(
  AppLocalizations l10n,
  SessionPhase phase,
  bool firstSession,
) => switch (phase) {
  SessionPhase.welcome =>
    firstSession ? l10n.suggestPhaseWelcome : l10n.sheetJumpRecall,
  SessionPhase.notionAndInitiation => l10n.sheetJumpTheory,
  SessionPhase.training => l10n.sheetJumpTraining,
  SessionPhase.game => l10n.sheetJumpGame,
  SessionPhase.review => l10n.sheetJumpReview,
};

/// Une phase de la séance : en-tête « Nom · N min » (minutes `[Prop]`) puis
/// son contenu.
/// Plafond de lecture (dp) des blocs de texte : seules les cartes d'exercice
/// profitent de la largeur de la page.
const double _readableWidth = 760;

/// Plafonne [child] à [_readableWidth], aligné à gauche.
class _Readable extends StatelessWidget {
  const _Readable({required this.child});

  final Widget child;

  // `Align` relâche la contrainte serrée de la colonne : sans lui, la boîte
  // contrainte ne pourrait pas être plus étroite que la page.
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.topStart,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _readableWidth),
      child: child,
    ),
  );
}

class _PhaseSection extends StatelessWidget {
  const _PhaseSection({
    required this.sectionKey,
    required this.phase,
    required this.minutes,
    required this.title,
    required this.children,
  });

  final GlobalKey sectionKey;
  final SessionPhase phase;
  final int minutes;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.suggestPhaseLine(title, minutes),
                  key: ValueKey('phase:${phase.name}'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const ProposalBadge(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final child in children) ...[
            if (child is _ExerciseCard) child else _Readable(child: child),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _RecallContent extends StatelessWidget {
  const _RecallContent({required this.scope});

  final _SheetScope scope;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sheet = scope.sheet;
    final recall = sheet.recall;
    final previous = scope.detail.previous;
    final reuse = recall.reuse;
    final reused = previous != null && reuse != null
        ? _illustrationOf(previous, reuse.illustration)
        : null;
    return _ElementCard(
      title: previous == null
          ? l10n.sheetFirstSession
          : l10n.sheetPrevious(
              l10n.sheetFullTitle(
                previous.title,
                previous.part,
                _partCountOf(previous, scope),
              ),
            ),
      badges: [_Source(element: 'recall', provenance: recall.src)],
      children: [
        _Bullets(recall.points),
        _Line(l10n.sheetFlashQuestion(recall.ask)),
        _Line(l10n.sheetFlashAnswer(recall.answer)),
        if (reused != null)
          SheetIllustrationView(
            illustration: reused,
            diagrams: scope.specs,
            proposal: recall.src.isProposal,
          ),
      ],
    );
  }

  static Illustration? _illustrationOf(SessionSheet sheet, String id) {
    for (final i in sheet.illustrations) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Nombre de séances de la technique de la séance précédente : celui de la
  /// séance affichée si c'est la même technique, sinon inconnu à cet écran
  /// (le titre de la technique suffit).
  static int _partCountOf(SessionSheet previous, _SheetScope scope) =>
      previous.technique == scope.sheet.technique
      ? scope.detail.partCount
      : previous.part;
}

class _TheoryCard extends StatelessWidget {
  const _TheoryCard({required this.scope, required this.section});

  final _SheetScope scope;
  final SheetTheorySection section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final demo = section.demo;
    return _ElementCard(
      title: section.title,
      minutes: scope.timing.theory[section.id],
      badges: [
        _Source(element: 'theory:${section.id}', provenance: section.src),
      ],
      children: [
        for (final paragraph in section.body) _Line(paragraph),
        if (scope.audience == Audience.adults)
          for (final extra in section.adultExtra)
            _Line(l10n.sheetAdultExtra(extra)),
        _Line(
          l10n.sheetKeyPoint(section.keyPoint),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (demo != null) _Line(l10n.sheetDemo(demo)),
        for (final id in section.illustrationIds)
          if (scope.illustration(id) case final illustration?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: SheetIllustrationView(
                illustration: illustration,
                diagrams: scope.specs,
                proposal: section.src.isProposal,
              ),
            ),
      ],
    );
  }
}

class _InitiationCard extends StatelessWidget {
  const _InitiationCard({required this.scope, required this.item});

  final _SheetScope scope;
  final SheetInitiation item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final illustrationId = item.illustrationId;
    final illustration = illustrationId == null
        ? null
        : scope.illustration(illustrationId);
    return _ElementCard(
      title: item.title,
      minutes: scope.timing.initiation[item.id],
      badges: [
        Text(
          l10n.sheetInitiationNumber(item.initiationSheet),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        _Source(element: 'initiation:${item.id}', provenance: item.src),
      ],
      children: [
        _Line(l10n.sheetSetup(item.setup)),
        _Line(l10n.sheetGoal(item.goal)),
        _Line(l10n.sheetExpected(item.expected)),
        _Line(switch (item.scoring) {
          CounterScoring(:final of) => l10n.sheetCounter(of),
          ChecklistScoring(:final criteria) => l10n.sheetChecklist(
            criteria.join(l10n.listSeparator),
          ),
        }),
        _Line(l10n.sheetNotRecorded),
        if (illustration != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: SheetIllustrationView(
              illustration: illustration,
              diagrams: scope.specs,
              proposal: item.src.isProposal,
            ),
          ),
      ],
    );
  }
}

/// Largeur de fenêtre dès laquelle la carte d'un exercice passe sur deux
/// colonnes : celle où la navigation passe en rail (cohérence des seuils).
const double _twoColumnsFrom = 720;

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.scope, required this.exercise});

  final _SheetScope scope;
  final SheetExercise exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spec = scope.detail.exerciseSpecs[exercise.id];
    final proposal = exercise.src.isProposal;
    final diagramSpec = scope.specs[exercise.diagramId];
    final wide = MediaQuery.sizeOf(context).width >= _twoColumnsFrom;
    final visual = KeyedSubtree(
      key: ValueKey('exercise-visual:${exercise.id}'),
      child: diagramSpec != null
          ? _ExerciseDiagram(
              spec: diagramSpec,
              number: exercise.ref.number,
              title: scope.sheet.title,
            )
          : _Line(
              scope.detail.diagramsUnreadable
                  ? l10n.diagramInvalid
                  : l10n.exerciseDiagramMissing,
            ),
    );
    final text = Column(
      key: ValueKey('exercise-text:${exercise.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spec != null) _CatalogueLine(spec: spec),
        if (proposal) _Line(l10n.sheetRateProposal),
        _Line(l10n.sheetPassesPlanned(exercise.passes)),
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
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Source(
              element: 'playful:${exercise.id}',
              provenance: Provenance.prop,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        _Line(l10n.sheetPlayfulHook(exercise.playful.hook)),
        _Line(l10n.sheetPlayfulChallenge(exercise.playful.challenge)),
      ],
    );
    return _ElementCard(
      title: l10n.sheetExerciseHeading(exercise.ref.number, exercise.title),
      minutes: scope.timing.exercises[exercise.id],
      badges: [
        _Source(element: 'exercise:${exercise.id}', provenance: exercise.src),
      ],
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: visual),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 6, child: text),
            ],
          )
        else ...[
          visual,
          text,
        ],
      ],
    );
  }
}

/// Taux, chevalet et mention bronze lus dans le catalogue d'entraînement.
class _CatalogueLine extends StatelessWidget {
  const _CatalogueLine({required this.spec});

  final ExerciseSpec spec;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.titleSmall;
    final bridge = spec.bridge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Line(
          l10n.sheetRequired(spec.rate.successes, spec.rate.attempts),
          style: style,
        ),
        if (bridge != null)
          _Line(
            bridge == Bridge.frame
                ? l10n.exerciseBridgeFrame
                : l10n.exerciseBridgeSurface,
          ),
        if (spec.bronze) _Line(l10n.exerciseBronze),
      ],
    );
  }
}

class _ExerciseDiagram extends StatelessWidget {
  const _ExerciseDiagram({
    required this.spec,
    required this.number,
    required this.title,
  });

  final ui.TableDiagramSpec spec;
  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: SheetIllustrationView.maxWidth,
          ),
          child: TableDiagramPlayer(
            spec: spec,
            semanticLabel: l10n.exerciseDiagramSemantics(number, title),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.scope});

  final _SheetScope scope;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final game = scope.sheet.game;
    final setupId = game.setupIllustrationId;
    final setup = setupId == null ? null : scope.illustration(setupId);
    final link = game.link;
    final adaptation = scope.audience == Audience.children
        ? game.adaptation.children
        : game.adaptation.adults;
    final materials = game.materials;
    final sourceGame = game.sourceGame;
    return _ElementCard(
      title: game.title,
      minutes: scope.timing.game,
      badges: [_Source(element: 'game', provenance: game.src)],
      children: [
        _Line(switch ((game.adapted, sourceGame)) {
          (true, final int n) => l10n.sheetGameAdapted(n),
          (false, final int n) => l10n.sheetGameSource(n),
          (_, null) => l10n.sheetGameNoSource,
        }),
        if (setup != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SheetIllustrationView(
              illustration: setup,
              diagrams: scope.specs,
              proposal: game.src.isProposal,
            ),
          ),
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
              scope.detail.previous?.title ?? link.notionOf.value,
              link.rule,
            ),
            detail: l10n.sheetGameLinkNote(link.note),
          ),
        if (adaptation != null)
          _ProposalLine(
            element: 'adaptation',
            text: l10n.sheetGameAdaptation(adaptation),
          ),
      ],
    );
  }
}

/// Ligne de texte `[Prop]` : le badge « Proposition » précède le texte.
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

class _ReviewContent extends StatelessWidget {
  const _ReviewContent({required this.sheet});

  final SessionSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: _Bullets([
          for (final prompt in sheet.reviewPrompts)
            l10n.sheetReviewPrompt(prompt),
        ]),
      ),
    );
  }
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({required this.sheet});

  final SessionSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ElementCard(
      title: l10n.sheetSources,
      children: [
        for (final SheetSourceRef source in sheet.sources)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ProvenanceBadge(provenance: source.rank),
                Text(
                  source.page == null
                      ? l10n.sheetSourceRowNoPage(source.file, source.note)
                      : l10n.sheetSourceRow(
                          source.file,
                          source.page!,
                          source.note,
                        ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        _Line(l10n.sheetProposalsNote),
        if (sheet.uncertainties.isNotEmpty) ...[
          Text(
            l10n.sheetUncertainties,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          _Bullets(sheet.uncertainties),
        ],
      ],
    );
  }
}
