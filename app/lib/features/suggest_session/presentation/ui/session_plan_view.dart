import 'package:billard_cfa/features/suggest_session/domain/exercise_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/features/suggest_session/domain/sheet_suggestion.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/audience_badge.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/exercise_title.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
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
    required this.onOpenSheet,
    required this.onLaunch,
    required this.onPlan,
    this.recall,
    super.key,
  });

  final SessionPlan plan;
  final List<ExerciseSheet> exercises;
  final ExerciseSheet? recall;
  final ValueChanged<ExerciseRef> onOpenSource;
  final VoidCallback onRecord;

  /// Ouvre la séance du catalogue proposée.
  final ValueChanged<SheetId> onOpenSheet;

  /// Lance la séance guidée de la séance du catalogue proposée.
  final ValueChanged<SheetId> onLaunch;

  /// Planifie la séance proposée ; `null` pour une notion sans séance du
  /// catalogue.
  final ValueChanged<SheetId?> onPlan;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(main.title, style: theme.textTheme.titleMedium),
              if (main.isProposal) ...[
                const SizedBox(height: AppSpacing.xs),
                const ProposalBadge(),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SheetCard(
          suggestion: plan.sheet,
          mainTitle: main.title,
          onOpen: onOpenSheet,
          onLaunch: onLaunch,
          onPlan: onPlan,
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

/// La séance du catalogue proposée et ses actions ; sans proposition, le
/// message de repli (notion sans séance) et la seule planification libre.
class _SheetCard extends StatelessWidget {
  const _SheetCard({
    required this.suggestion,
    required this.mainTitle,
    required this.onOpen,
    required this.onLaunch,
    required this.onPlan,
  });

  final SheetSuggestion? suggestion;
  final String mainTitle;
  final ValueChanged<SheetId> onOpen;
  final ValueChanged<SheetId> onLaunch;
  final ValueChanged<SheetId?> onPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final suggestion = this.suggestion;
    if (suggestion == null) {
      return SectionCard(
        title: l10n.suggestSheetTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.suggestSheetNone),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => onPlan(null),
              child: Text(l10n.suggestSheetPlan),
            ),
          ],
        ),
      );
    }
    final option = suggestion.option;
    final reason = switch (suggestion.kind) {
      SheetSuggestionKind.nextPending => l10n.suggestSheetNextPending,
      SheetSuggestionKind.coversHead => l10n.suggestSheetCoversHead,
      SheetSuggestionKind.repeat => l10n.suggestSheetRepeat(
        MaterialLocalizations.of(context)
            .formatMediumDate(suggestion.lastGivenOn!),
      ),
    };
    return SectionCard(
      title: l10n.suggestSheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Le titre de la notion est déjà celui de la carte précédente.
          if (option.title != mainTitle)
            Text(option.title, style: theme.textTheme.titleMedium),
          Text(l10n.sheetPartLabel(option.part, option.partCount)),
          Text(reason, style: theme.textTheme.bodyMedium),
          if (!suggestion.headCovered)
            Text(
              l10n.suggestSheetHeadElsewhere(suggestion.head.number),
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.tonal(
                onPressed: () => onOpen(option.id),
                child: Text(l10n.suggestSheetOpen),
              ),
              FilledButton.tonal(
                onPressed: () => onLaunch(option.id),
                child: Text(l10n.suggestSheetLaunch),
              ),
              OutlinedButton(
                onPressed: () => onPlan(option.id),
                child: Text(l10n.suggestSheetPlan),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
                  exerciseTitle(
                    l10n,
                    blockTitle: sheet.block.title,
                    number: sheet.spec.ref.number,
                    proposal: sheet.block.isProposal,
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
