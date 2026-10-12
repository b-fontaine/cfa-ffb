import 'package:billard_cfa/features/suggest_session/domain/exercise_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/ui/audience_badge.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Séance suggérée : durée, notion principale, minutage, exercices avec lien
/// vers leur fiche source, rappel et jeu.
class SessionPlanView extends StatelessWidget {
  const SessionPlanView({
    required this.plan,
    required this.exercises,
    required this.onOpenSource,
    required this.onRecord,
    this.recall,
    super.key,
  });

  final SessionPlan plan;
  final List<ExerciseSheet> exercises;
  final ExerciseSheet? recall;
  final ValueChanged<ExerciseRef> onOpenSource;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final main = exercises.first.block;
    final recall = this.recall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AudienceBadge(kind: plan.audience.kind),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.sessionDurationMinutes(plan.durationMinutes),
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: l10n.suggestMainNotion,
          child: Text(main.title, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: l10n.suggestPhases,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final slot in plan.phases)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    l10n.suggestPhaseLine(
                      _phaseName(l10n, slot.phase),
                      slot.minutes,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: l10n.suggestExercises,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final sheet in exercises)
                _ExerciseLine(sheet: sheet, onOpenSource: onOpenSource),
              Text(
                l10n.suggestMaxPasses(plan.maxPassesPerExercise),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: l10n.suggestRecall,
          child: recall == null
              ? Text(l10n.suggestRecallNone)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ExerciseLine(sheet: recall, onOpenSource: onOpenSource),
                    Text(
                      _reason(l10n, plan.recallReason),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: onRecord, child: Text(l10n.suggestRecord)),
      ],
    );
  }

  String _reason(AppLocalizations l10n, RecallReason? reason) =>
      switch (reason) {
        RecallReason.groupFailure => l10n.suggestReasonGroupFailure,
        RecallReason.activeAlert => l10n.suggestReasonActiveAlert,
        RecallReason.lastFailed => l10n.suggestReasonLastFailed,
        RecallReason.stale => l10n.suggestReasonStale,
        null => '',
      };

  String _phaseName(AppLocalizations l10n, SessionPhase phase) =>
      switch (phase) {
        SessionPhase.welcome => l10n.suggestPhaseWelcome,
        SessionPhase.notionAndInitiation => l10n.suggestPhaseNotion,
        SessionPhase.training => l10n.suggestPhaseTraining,
        SessionPhase.game => l10n.suggestPhaseGame,
        SessionPhase.review => l10n.suggestPhaseReview,
      };
}

class _ExerciseLine extends StatelessWidget {
  const _ExerciseLine({required this.sheet, required this.onOpenSource});

  final ExerciseSheet sheet;
  final ValueChanged<ExerciseRef> onOpenSource;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rate = sheet.spec.rate;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sheetExerciseTitle(
                    sheet.block.title,
                    sheet.spec.ref.number,
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  l10n.sheetRequired(rate.successes, rate.attempts),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => onOpenSource(sheet.spec.ref),
            child: Text(l10n.suggestSource),
          ),
        ],
      ),
    );
  }
}
