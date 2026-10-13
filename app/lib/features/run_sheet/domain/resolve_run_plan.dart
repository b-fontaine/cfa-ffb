import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_grouping.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/features/run_sheet/domain/results_recall_block.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : le déroulé d'une séance du catalogue pour un public.
///
/// Accueil ou rappel, théorie, initiation, exercices, jeu, bilan, avec les
/// minutes calculées (`RulesConfig.shapes`), les taux du catalogue
/// d'entraînement, les schémas par identifiant et le bloc du rappel de
/// résultats. Sans `audience`, le public est celui de la séance planifiée
/// `sessionId` ; à défaut, les enfants. Identifiant inconnu :
/// `NotFound('sheet', id)`. Des schémas illisibles ne font pas échouer le
/// déroulé.
@injectable
class ResolveRunPlan {
  ResolveRunPlan(
    this._sheets,
    this._sessions,
    this._catalogue,
    this._diagrams,
    this._rules,
  );

  final SessionSheetRepository _sheets;
  final SessionRepository _sessions;
  final CatalogueRepository _catalogue;
  final DiagramRepository _diagrams;
  final RulesConfig _rules;

  Future<Result<RunPlan>> call(
    SheetId id, {
    Audience? audience,
    String? sessionId,
  }) => runGuarded(() async {
    final sheet = await _sheets.getById(id);
    if (sheet == null) throw NotFound('sheet', id.value);
    final all = await _sheets.getAll();
    final resolved = audience ?? await _plannedAudience(sessionId);
    final previousId = sheet.previous;
    final previous = previousId == null
        ? null
        : await _sheets.getById(previousId);
    final catalogue = await _catalogue.load();
    final specs = <String, ExerciseSpec>{
      for (final e in sheet.exercises) e.id: ?catalogue.exercise(e.ref),
    };
    final wanted = diagramIdsOf(sheet, previous);
    var unreadable = false;
    final diagrams = <String, ExerciseDiagram>{};
    try {
      final library = await _diagrams.load();
      for (final diagramId in wanted) {
        final diagram = library.byId(diagramId);
        if (diagram != null) diagrams[diagramId] = diagram;
      }
    } on InvariantViolation catch (violation) {
      // Seul « schéma illisible » est toléré ; le reste est une vraie erreur.
      if (violation.code != InvariantCode.invalidDiagram) rethrow;
      unreadable = true;
    }
    final timing = sheetTiming(
      sheet,
      audience: resolved,
      shapes: _rules.shapes,
    );
    return RunPlan(
      sheet: sheet,
      audience: resolved,
      partCount: partCountOf(all, sheet.technique),
      timing: timing,
      steps: _steps(sheet, resolved, timing),
      passesRequired: _rules.passesRequired,
      previous: previous,
      previousPartCount: previous == null
          ? null
          : partCountOf(all, previous.technique),
      recallBlockId: resultsRecallBlock(sheet, all),
      blockTitle: catalogue.blockById(sheet.catalogueBlock)?.title,
      exerciseSpecs: specs,
      diagrams: diagrams,
      diagramsUnreadable: unreadable,
    );
  });

  Future<Audience> _plannedAudience(String? sessionId) async {
    if (sessionId == null) return Audience.children;
    final sessions = await _sessions.getAll();
    return sessions.where((s) => s.id == sessionId).firstOrNull?.audience ??
        Audience.children;
  }

  static List<RunStep> _steps(
    SessionSheet sheet,
    Audience audience,
    SheetTiming timing,
  ) => [
    RunStep(
      kind: RunStepKind.recall,
      phase: SessionPhase.welcome,
      minutes: timing.recall,
    ),
    for (final s in sheet.theorySections)
      if (s.weight.isShownFor(audience))
        RunStep(
          kind: RunStepKind.theory,
          phase: SessionPhase.notionAndInitiation,
          minutes: timing.theory[s.id] ?? 0,
          elementId: s.id,
        ),
    for (final i in sheet.initiation)
      if (i.weight.isShownFor(audience))
        RunStep(
          kind: RunStepKind.initiation,
          phase: SessionPhase.notionAndInitiation,
          minutes: timing.initiation[i.id] ?? 0,
          elementId: i.id,
        ),
    for (final e in sheet.exercises)
      if (e.weight.isShownFor(audience))
        RunStep(
          kind: RunStepKind.exercise,
          phase: SessionPhase.training,
          minutes: timing.exercises[e.id] ?? 0,
          elementId: e.id,
        ),
    RunStep(
      kind: RunStepKind.game,
      phase: SessionPhase.game,
      minutes: timing.game,
    ),
    RunStep(
      kind: RunStepKind.review,
      phase: SessionPhase.review,
      minutes: timing.review,
    ),
  ];
}
