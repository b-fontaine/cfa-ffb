import 'package:billard_cfa/features/run_sheet/domain/run_plan.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';

/// Nom localisé d'une phase de séance.
String runPhaseTitle(AppLocalizations l10n, SessionPhase phase) =>
    switch (phase) {
      SessionPhase.welcome => l10n.suggestPhaseWelcome,
      SessionPhase.notionAndInitiation => l10n.suggestPhaseNotion,
      SessionPhase.training => l10n.suggestPhaseTraining,
      SessionPhase.game => l10n.suggestPhaseGame,
      SessionPhase.review => l10n.suggestPhaseReview,
    };

/// Titre d'une étape : celui de son élément (le contenu est en français).
String runStepTitle(AppLocalizations l10n, RunPlan plan, RunStep step) {
  final sheet = plan.sheet;
  return switch (step.kind) {
    RunStepKind.recall =>
      plan.previous == null ? l10n.suggestPhaseWelcome : l10n.sheetPhaseRecall,
    RunStepKind.theory => plan.theoryOf(step)?.title ?? '',
    RunStepKind.initiation => plan.initiationOf(step)?.title ?? '',
    RunStepKind.exercise => l10n.sheetExerciseHeading(
      plan.exerciseOf(step)?.ref.number ?? 0,
      plan.exerciseOf(step)?.title ?? '',
    ),
    RunStepKind.game => sheet.game.title,
    RunStepKind.review => l10n.suggestPhaseReview,
  };
}

/// « mm:ss » d'une durée en secondes.
String runClock(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${rest.toString().padLeft(2, '0')}';
}
