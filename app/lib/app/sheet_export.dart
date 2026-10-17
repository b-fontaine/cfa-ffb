import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart'
    as diagram;
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_exercise.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_source.dart';
import 'package:billard_cfa/features/export_sheet/domain/export_source.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_labels.dart';
import 'package:billard_cfa/features/export_sheet/domain/results_sheets_input.dart';
import 'package:billard_cfa/features/export_sheet/domain/sheet_print_input.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/run_step_titles.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart' as pocket;
import 'package:billard_cfa/shared/ui/audience_labels.dart';

// Correspondance entre le déroulé d'une séance du catalogue (`run_sheet`) et ce
// que la feature d'export imprime (ADR 0021). Une feature ne peut pas en
// importer une autre : la couche `app` fait le lien. Rien ici ne lit ni ne
// produit de donnée d'élève.

/// Résout le déroulé d'une séance pour un public, sans choisir l'exercice du
/// créneau de rappel (aucun élève lu).
typedef ResolvePlan = Future<Result<RunPlan>> Function(
  SheetId id,
  Audience audience,
);

/// [ExportSource] fondée sur le déroulé de la séance [sheetId].
class RunPlanExportSource implements ExportSource {
  RunPlanExportSource({
    required this.sheetId,
    required this.l10n,
    required this.printedOn,
    required this.resolve,
  });

  final SheetId sheetId;
  final AppLocalizations l10n;

  /// Date d'impression, déjà mise en forme (jour seul).
  final String printedOn;
  final ResolvePlan resolve;

  @override
  Future<Result<SheetPrintInput>> animator(Audience audience) async =>
      switch (await resolve(sheetId, audience)) {
        Ok(:final value) => Ok(
          sheetPrintInputFrom(value, l10n, printedOn: printedOn),
        ),
        Err(:final failure) => Err(failure),
      };

  @override
  Future<Result<ResultsPlan>> results(Audience audience) async =>
      switch (await resolve(sheetId, audience)) {
        Ok(:final value) => Ok(resultsPlanFrom(value, l10n)),
        Err(:final failure) => Err(failure),
      };
}

/// Libellés fixes de la feuille de l'animateur, dans la langue de [l10n].
PrintLabels printLabelsOf(AppLocalizations l10n) => PrintLabels(
  rundown: l10n.printRundown,
  columnTime: l10n.printColumnTime,
  columnStep: l10n.printColumnStep,
  columnMinutes: l10n.printColumnMinutes,
  total: (minutes) => l10n.printTotal(minutes),
  minutesNote: l10n.printMinutesNote,
  proposalLegend: l10n.printProposalLegend,
  sources: l10n.printSources,
  uncertainties: l10n.printUncertainties,
  illustrationAlt: l10n.printIllustrationAlt,
  ballLegend: l10n.printBallLegend,
  pageOf: (page, pages) => l10n.printPageOf(page, pages),
  minutes: (minutes) => l10n.printMinutes(minutes),
  thetaWord: l10n.printThetaWord,
);

/// Libellés fixes des fiches résultats, dans la langue de [l10n].
ResultsLabels resultsLabelsOf(AppLocalizations l10n) => ResultsLabels(
  language: l10n.localeName,
  title: l10n.printResultsTitle,
  tabBrand: l10n.printResultsTabBrand,
  tabTitle: l10n.printResultsTabTitle,
  sourceLine: l10n.printResultsSourceLine,
  notFederalLine: l10n.printResultsNotFederal,
  name: l10n.printResultsName,
  totalFirstLine: l10n.printResultsTotalFirst,
  totalSecondLine: l10n.printResultsTotalSecond,
  attempt: l10n.printResultsAttempt,
  attemptLegend: (number) => l10n.printResultsAttemptLegend(number),
  session: l10n.printResultsSession,
  exercise: l10n.printResultsExercise,
  notion: l10n.printResultsNotion,
  technique: l10n.printResultsTechnique,
  thetaWord: l10n.printThetaWord,
);

String _fileName(AppLocalizations l10n, RunPlan plan, {required bool results}) {
  final audience = switch (plan.audience) {
    Audience.children => l10n.printFileChildren,
    Audience.adults => l10n.printFileAdults,
  };
  final id = plan.sheet.id.value;
  return results
      ? l10n.printFileResults(id, audience)
      : l10n.printFileSession(id, audience);
}

/// L'entrée de la feuille de l'animateur pour [plan] : déroulé, minutes
/// calculées, consignes, schémas, provenance et sources. Sans aucune donnée
/// d'élève : le créneau de rappel n'y nomme aucun exercice.
SheetPrintInput sheetPrintInputFrom(
  RunPlan plan,
  AppLocalizations l10n, {
  required String printedOn,
}) {
  final sheet = plan.sheet;
  final title = l10n.sheetFullTitle(sheet.title, sheet.part, plan.partCount);
  return SheetPrintInput(
    fileName: _fileName(l10n, plan, results: false),
    title: title,
    shortTitle: sheet.title,
    language: l10n.localeName,
    headerLines: [
      l10n.printAudienceLine(plan.audience.label(l10n), plan.timing.total),
      l10n.printNotionLine(sheet.notion),
      l10n.printLevelLine(printedOn),
    ],
    steps: [for (final step in plan.steps) _step(plan, l10n, step)],
    sources: [for (final s in sheet.sources) _sourceLine(l10n, s)],
    uncertainties: sheet.uncertainties,
    labels: printLabelsOf(l10n),
  );
}

String _rankMark(Provenance rank) => switch (rank) {
  Provenance.s => '[S]',
  Provenance.ffb => '[FFB]',
  Provenance.web => '[Web]',
  Provenance.prop => '[Prop]',
};

String _sourceLine(AppLocalizations l10n, SheetSourceRef source) {
  final rank = _rankMark(source.rank);
  final page = source.page;
  return page == null
      ? l10n.printSourceLineNoPage(rank, source.file, source.note)
      : l10n.printSourceLine(rank, source.file, page, source.note);
}

SheetPrintStep _step(RunPlan plan, AppLocalizations l10n, RunStep step) {
  final sheet = plan.sheet;
  final blocks = <SheetPrintBlock>[];
  Provenance? source;
  var title = runStepTitle(l10n, plan, step);
  switch (step.kind) {
    case RunStepKind.recall:
      source = sheet.recall.src;
      blocks.addAll([
        SheetPrintList(sheet.recall.points, label: l10n.printRecallPoints),
        SheetPrintText(sheet.recall.ask, label: l10n.printQuestion),
        SheetPrintText(sheet.recall.answer, label: l10n.printAnswer),
      ]);
    case RunStepKind.theory:
      final theory = plan.theoryOf(step);
      if (theory != null) {
        source = theory.src;
        blocks.add(SheetPrintText(theory.keyPoint, label: l10n.printKeyPoint));
        final demo = theory.demo;
        if (demo != null && demo.isNotEmpty) {
          blocks.add(SheetPrintText(demo, label: l10n.printDemo));
        }
      }
    case RunStepKind.initiation:
      final initiation = plan.initiationOf(step);
      if (initiation != null) {
        source = initiation.src;
        blocks.addAll([
          SheetPrintText(initiation.setup, label: l10n.printSetup),
          SheetPrintText(initiation.goal, label: l10n.printGoal),
          SheetPrintText(initiation.expected, label: l10n.printExpected),
          SheetPrintText(switch (initiation.scoring) {
            CounterScoring(:final of) => l10n.printScoringCounter(of),
            ChecklistScoring() => l10n.printScoringChecklist,
          }, label: l10n.printScoring),
          if (initiation.scoring case ChecklistScoring(:final criteria))
            SheetPrintList(criteria),
        ]);
      }
    case RunStepKind.exercise:
      final exercise = plan.exerciseOf(step);
      if (exercise != null) {
        source = exercise.src;
        blocks.addAll(_exerciseBlocks(plan, l10n, step, exercise));
      }
    case RunStepKind.recallExercise:
      title = l10n.printRecallSlot;
      blocks.add(SheetPrintText(l10n.printRecallSlotNote));
    case RunStepKind.game:
      source = sheet.game.src;
      blocks.addAll(_gameBlocks(plan, l10n));
    case RunStepKind.review:
      blocks.add(SheetPrintList(sheet.reviewPrompts));
  }
  for (final illustration in plan.illustrationsOf(step)) {
    blocks.add(_illustrationBlock(plan, illustration));
  }
  return SheetPrintStep(
    phase: runPhaseTitle(l10n, step.phase),
    title: title,
    minutes: step.minutes,
    source: source,
    blocks: blocks,
  );
}

List<SheetPrintBlock> _exerciseBlocks(
  RunPlan plan,
  AppLocalizations l10n,
  RunStep step,
  SheetExercise exercise,
) {
  final spec = plan.specOf(step);
  final drawing = plan.diagrams[exercise.diagramId];
  return [
    SheetPrintText(exercise.setup, label: l10n.printSetup),
    SheetPrintText(exercise.instruction, label: l10n.printInstruction),
    SheetPrintText(exercise.expected, label: l10n.printExpected),
    if (spec != null)
      SheetPrintText(
        l10n.printRateValue(spec.rate.successes, spec.rate.attempts),
        label: l10n.printRate,
      ),
    SheetPrintText(
      l10n.printPassesValue(exercise.passes),
      label: l10n.printPasses,
    ),
    if (exercise.mistakes.isNotEmpty)
      SheetPrintList([
        for (final m in exercise.mistakes) l10n.printMistake(m.symptom, m.fix),
      ], label: l10n.printMistakes),
    SheetPrintText(
      exercise.playful.hook,
      label: l10n.printHook,
      proposal: true,
    ),
    SheetPrintText(
      exercise.playful.challenge,
      label: l10n.printChallenge,
      proposal: true,
    ),
    if (drawing != null) _diagramBlock(drawing),
  ];
}

SheetPrintDiagram _diagramBlock(ExerciseDiagram drawing) => SheetPrintDiagram(
  table: drawing.table,
  caption: drawing.caption,
  description: drawing.description,
);

List<SheetPrintBlock> _gameBlocks(RunPlan plan, AppLocalizations l10n) {
  final game = plan.sheet.game;
  final adaptation = plan.audience == Audience.children
      ? game.adaptation.children
      : game.adaptation.adults;
  final materials = game.materials;
  final link = game.link;
  return [
    SheetPrintText(game.players, label: l10n.printPlayers),
    if (materials != null && materials.isNotEmpty)
      SheetPrintText(materials, label: l10n.printMaterials),
    SheetPrintList(game.rules, label: l10n.printRules),
    SheetPrintText(game.scoring, label: l10n.printGameScoring),
    SheetPrintText(game.end, label: l10n.printGameEnd),
    SheetPrintText(
      game.playfulVariant,
      label: l10n.printVariant,
      proposal: true,
    ),
    if (adaptation != null)
      SheetPrintText(adaptation, label: l10n.printAdaptation, proposal: true),
    if (link != null)
      SheetPrintText(
        l10n.printLinkValue(link.rule, link.note),
        label: l10n.printLink,
        proposal: true,
      ),
  ];
}

SheetPrintBlock _illustrationBlock(RunPlan plan, Illustration illustration) =>
    switch (illustration) {
      DiagramRefIllustration(:final diagramId)
          when plan.diagrams.containsKey(diagramId) =>
        SheetPrintDiagram(
          table: plan.diagrams[diagramId]!.table,
          caption: illustration.caption,
          description: illustration.alt,
        ),
      TableIllustration() => SheetPrintDiagram(
        table: _tableOf(illustration),
        caption: illustration.caption,
        description: illustration.alt,
      ),
      _ => SheetPrintCaption(
        caption: illustration.caption,
        alt: illustration.alt,
      ),
    };

diagram.DiagramTable _tableOf(TableIllustration table) => diagram.DiagramTable(
  balls: [
    for (final b in table.balls)
      diagram.TableBall(
        id: b.id,
        color: diagram.TableBallColor.values.byName(b.color.name),
        at: b.at,
        role: b.role == null
            ? null
            : diagram.TableBallRole.values.byName(b.role!.name),
        label: b.label,
        order: b.order,
      ),
  ],
  ghosts: [
    for (final g in table.ghosts)
      diagram.TableGhost(
        id: g.id,
        at: g.at,
        role: diagram.TableGhostRole.values.byName(g.role.name),
        forBallId: g.forBallId,
        label: g.label,
      ),
  ],
  arrows: [
    for (final a in table.arrows)
      diagram.TableArrow(
        id: a.id,
        kind: diagram.TableArrowKind.values.byName(a.kind.name),
        path: a.path,
        ballId: a.ballId,
        bounces: [
          for (final band in a.bounces)
            diagram.TableBand.values.byName(band.name),
        ],
        pocket: a.pocket == null ? null : _pocketOf(a.pocket!),
        label: a.label,
        note: a.note,
      ),
  ],
  zones: [
    for (final z in table.zones)
      diagram.TableZone(id: z.id, from: z.from, to: z.to, label: z.label),
  ],
);

diagram.TablePocket _pocketOf(pocket.TablePocket value) =>
    diagram.TablePocket.values.byName(value.name);

/// Les séries des fiches résultats pour [plan] : une par exercice
/// d'entraînement affiché pour le public (le créneau de rappel n'est pas
/// imprimé : son exercice est inconnu). Les libellés fixes suivent la langue de
/// l'interface.
ResultsPlan resultsPlanFrom(RunPlan plan, AppLocalizations l10n) {
  final sheet = plan.sheet;
  return ResultsPlan(
    title: l10n.printResultsDocTitle(sheet.title),
    fileName: _fileName(l10n, plan, results: true),
    columns: plan.passesRequired,
    labels: resultsLabelsOf(l10n),
    series: [
      for (final step in plan.steps)
        if (step.kind == RunStepKind.exercise)
          ResultsSeries(
            session: l10n.printResultsSessionLine(
              sheet.title,
              sheet.part,
              plan.partCount,
            ),
            exercise:
                '${plan.exerciseOf(step)!.ref.number}. '
                '${plan.exerciseOf(step)!.title}',
            notion: sheet.notion,
            technique: sheet.title,
            attempts: plan.specOf(step)?.rate.attempts,
          ),
    ],
  );
}
