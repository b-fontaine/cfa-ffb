import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart' as alert;
import 'package:billard_cfa/shared/ui/exercise_title.dart';
import 'package:billard_cfa/shared/ui/page_header.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/session_tag_picker.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/watch_row.dart';
import 'package:flutter/material.dart';

/// Le bilan d'une séance donnée : en-tête, passages par exercice, validations
/// du jour, présents sans passage, élèves à surveiller, puis [next] (la séance
/// suivante, composée par la page : cette slice ne connaît pas les autres).
///
/// Sans aucun passage, le bilan le dit, propose de saisir les résultats et
/// n'affiche pas [next] : la règle du lot 8 reproposerait la même séance.
class SessionReviewView extends StatelessWidget {
  const SessionReviewView({
    required this.review,
    required this.onEnterResults,
    required this.onOpenRecord,
    required this.onOpenStudent,
    required this.onBackToday,
    required this.onTagsChanged,
    this.tagsNotSaved = false,
    this.next,
    super.key,
  });

  final SessionReview review;
  final Widget? next;
  final VoidCallback onEnterResults;
  final VoidCallback onOpenRecord;
  final ValueChanged<StudentId> onOpenStudent;
  final VoidCallback onBackToday;

  /// Les étiquettes de la note de jeu ont changé (liste fermée, ADR 0023).
  final ValueChanged<Set<SessionTag>> onTagsChanged;

  /// La dernière écriture des étiquettes a échoué : elles sont revenues à
  /// leur valeur d'avant.
  final bool tagsNotSaved;

  String _exercise(AppLocalizations l10n, ExerciseRef ref) {
    final label = review.blockLabels[ref.blockId];
    return exerciseTitle(
      l10n,
      blockTitle: label?.title ?? ref.blockId,
      number: ref.number,
      proposal: label?.proposal ?? false,
    );
  }

  String _name(StudentId id) => review.students[id]?.firstName ?? id.value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final outcome = review.outcome;
    final sheet = review.sheet;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(review.record.date);
    final present = review.record.present.length;
    final group = review.group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(title: l10n.reviewTitle, showLogo: false),
        const SizedBox(height: AppSpacing.sm),
        Text(
          sheet == null
              ? l10n.reviewSheetUnknown
              : l10n.sheetFullTitle(sheet.title, sheet.part, sheet.partCount),
          style: theme.textTheme.titleMedium,
        ),
        Text(
          group == null
              ? l10n.reviewMetaNoGroup(date, present)
              : l10n.reviewMeta(date, group.name, present),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        if (outcome.isEmpty)
          SectionCard(
            title: l10n.reviewPassesTitle,
            emphasis: SectionEmphasis.medium,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.reviewNoPasses),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: onEnterResults,
                  child: Text(l10n.reviewEnterResults),
                ),
              ],
            ),
          )
        else ...[
          SectionCard(
            title: l10n.reviewPassesTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reviewPassesTotal(
                    outcome.totalPasses,
                    outcome.totalPassed,
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                for (final entry in outcome.byExercise)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(child: Text(_exercise(l10n, entry.exercise))),
                        Text(
                          l10n.reviewExercisePasses(entry.passes, entry.passed),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: l10n.reviewValidatedTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (outcome.validations.isEmpty) Text(l10n.reviewNoValidation),
                for (final validation in outcome.validations)
                  Text(
                    l10n.reviewValidated(
                      _name(validation.studentId),
                      _exercise(l10n, validation.exercise),
                    ),
                    style: theme.textTheme.bodyLarge,
                  ),
              ],
            ),
          ),
        ],
        if (outcome.unrated.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: l10n.reviewUnratedTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final id in outcome.unrated)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(_name(id), style: theme.textTheme.bodyLarge),
                  ),
              ],
            ),
          ),
        ],
        if (outcome.watched.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: l10n.reviewWatchTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final watched in outcome.watched)
                  WatchRow(
                    name: _name(watched.studentId),
                    persistent: watched.alert == AlertLevel.persistent,
                    detail: l10n.homeWatchDetail(
                      _exercise(l10n, watched.exercise),
                      watched.consecutiveFailures,
                      watched.otherAlerts,
                    ),
                    onTap: () => onOpenStudent(watched.studentId),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: l10n.sessionTagsTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.sessionTagsHint, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              SessionTagPicker(
                selected: review.record.tags,
                onChanged: onTagsChanged,
              ),
              if (tagsNotSaved) ...[
                const SizedBox(height: AppSpacing.sm),
                alert.AppAlert(
                  level: alert.AlertLevel.persistent,
                  message: l10n.sessionTagsNotSaved,
                ),
              ],
            ],
          ),
        ),
        if (next != null && !outcome.isEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          next!,
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton(
              onPressed: onOpenRecord,
              child: Text(l10n.reviewSeeRecord),
            ),
            FilledButton(
              onPressed: onBackToday,
              child: Text(l10n.reviewBackToday),
            ),
          ],
        ),
      ],
    );
  }
}
