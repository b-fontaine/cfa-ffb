import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';

import 'session_sheet_fixtures.dart';

/// Séance de 5 étapes (0 à 4), une initiation à compteur sur 2 essais
/// (`ini`) et une grille de 2 critères (`grille`).
RunPlan runPlanFixture() {
  final sheet = buildSheet(
    initiation: [
      sheetInitiation('ini', scoring: const Scoring.counter(of: 2)),
      sheetInitiation(
        'grille',
        scoring: const Scoring.checklist(criteria: ['a', 'b']),
      ),
    ],
  );
  return RunPlan(
    sheet: sheet,
    audience: Audience.children,
    partCount: 2,
    timing: sheetTiming(
      sheet,
      audience: Audience.children,
      shapes: RulesConfig().shapes,
    ),
    steps: const [
      RunStep(
        kind: RunStepKind.recall,
        phase: SessionPhase.welcome,
        minutes: 10,
      ),
      RunStep(
        kind: RunStepKind.theory,
        phase: SessionPhase.notionAndInitiation,
        minutes: 20,
        elementId: 't1',
      ),
      RunStep(
        kind: RunStepKind.initiation,
        phase: SessionPhase.notionAndInitiation,
        minutes: 5,
        elementId: 'ini',
      ),
      RunStep(
        kind: RunStepKind.exercise,
        phase: SessionPhase.training,
        minutes: 35,
        elementId: 'e1',
      ),
      RunStep(kind: RunStepKind.game, phase: SessionPhase.game, minutes: 20),
    ],
    passesRequired: 5,
  );
}
