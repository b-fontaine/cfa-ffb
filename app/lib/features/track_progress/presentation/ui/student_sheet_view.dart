import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart'
    as result;
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/block_progress_list.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/exercise_curve_card.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/audience_badge.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/exercise_title.dart' as title;
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Fiche élève : synthèse, alertes, exercice suivant, progression par bloc et
/// courbes de performance. [recall] est la carte de notion à rappeler, fournie
/// par la page (autre fonctionnalité).
class StudentSheetView extends StatelessWidget {
  const StudentSheetView({required this.sheet, this.recall, super.key});

  final StudentSheet sheet;
  final Widget? recall;

  /// Titre localisé « bloc · exercice n ».
  static String exerciseTitle(
    AppLocalizations l10n,
    StudentSheet sheet,
    ExerciseRef ref,
  ) {
    final block = sheet.catalogue.blockById(ref.blockId);
    return title.exerciseTitle(
      l10n,
      blockTitle: block?.title ?? ref.blockId,
      number: ref.number,
      proposal: block?.isProposal ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final next = sheet.nextExercise;
    final recall = this.recall;
    final practised = {for (final s in sheet.series) s.exercise: s};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AudienceBadge(kind: sheet.student.currentAudience.kind),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.sheetValidatedTotal(
            sheet.report.validatedCount,
            sheet.report.exerciseCount,
          ),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        if (sheet.report.activeAlerts.isNotEmpty) ...[
          for (final alert in sheet.report.activeAlerts) ...[
            AppAlert(
              level: alert.alert == result.AlertLevel.persistent
                  ? AlertLevel.persistent
                  : AlertLevel.attention,
              message: l10n.sheetAlertConsecutive(
                exerciseTitle(l10n, sheet, alert.exercise),
                alert.consecutiveFailures,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xs),
        ],
        SectionCard(
          title: l10n.sheetNext,
          child: Text(
            next == null
                ? l10n.sheetNextNone
                : exerciseTitle(l10n, sheet, next),
            style: theme.textTheme.bodyLarge,
          ),
        ),
        if (recall != null) ...[const SizedBox(height: AppSpacing.md), recall],
        const SizedBox(height: AppSpacing.md),
        BlockProgressList(sheet: sheet),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text(l10n.sheetCurves, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (practised.isEmpty)
          Text(l10n.sheetCurvesEmpty, style: theme.textTheme.bodyLarge)
        else
          for (final series in sheet.series) ...[
            ExerciseCurveCard(
              series: series,
              title: exerciseTitle(l10n, sheet, series.exercise),
              passesRequired: sheet.passesRequired,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}
