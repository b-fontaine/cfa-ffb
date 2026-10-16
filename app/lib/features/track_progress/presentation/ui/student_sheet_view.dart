import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/exercise_curve_card.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/exercise_curve_sheet.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/path_list.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/sheet_header_card.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/ui/audience_badge.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/exercise_title.dart' as title;
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Fiche élève : en-tête (en cours, prochain, alerte), notion à rappeler,
/// assiduité, parcours en cases et courbes de performance repliées.
///
/// [recall] est la carte de notion à rappeler, fournie par la page (autre
/// fonctionnalité). [onAcknowledge] et [onRestore] (acquittement d'une
/// alerte, ADR 0013) puis [onMarkAcquired] et [onRevokeAcquired]
/// (positionnement, ADR 0008) sont aussi fournis par la page.
class StudentSheetView extends StatelessWidget {
  const StudentSheetView({
    required this.sheet,
    this.recall,
    this.onAcknowledge,
    this.onRestore,
    this.onMarkAcquired,
    this.onRevokeAcquired,
    super.key,
  });

  final StudentSheet sheet;
  final Widget? recall;
  final ValueChanged<ExerciseRef>? onAcknowledge;
  final ValueChanged<ExerciseRef>? onRestore;
  final ValueChanged<String>? onMarkAcquired;
  final ValueChanged<String>? onRevokeAcquired;

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
    final recall = this.recall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AudienceBadge(kind: sheet.student.currentAudience.kind),
        ),
        const SizedBox(height: AppSpacing.sm),
        SheetHeaderCard(
          header: sheet.header,
          titleOf: (ref) => exerciseTitle(l10n, sheet, ref),
          onAcknowledge: onAcknowledge,
          onRestore: onRestore,
        ),
        if (recall != null) ...[const SizedBox(height: AppSpacing.md), recall],
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: l10n.sheetAttendanceTitle,
          child: Text(
            sheet.report.attendance.isEmpty
                ? l10n.sheetAttendanceNone
                : l10n.sheetAttendance(
                    sheet.report.attendance.attended,
                    sheet.report.attendance.total,
                  ),
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PathList(
          sheet: sheet,
          onOpenExercise: (exercise) => showExerciseCurveSheet(
            context,
            sheet: sheet,
            exercise: exercise,
            title: exerciseTitle(l10n, sheet, exercise),
          ),
          onMarkAcquired: onMarkAcquired,
          onRevokeAcquired: onRevokeAcquired,
        ),
        const SizedBox(height: AppSpacing.md),
        _Curves(sheet: sheet),
      ],
    );
  }
}

/// Les courbes de performance, repliées par défaut : la fiche se lit d'abord
/// en cases.
class _Curves extends StatelessWidget {
  const _Curves({required this.sheet});

  final StudentSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.mediumRadius),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        title: Semantics(
          header: true,
          child: Text(l10n.sheetCurves, style: theme.textTheme.titleMedium),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sheet.series.isEmpty)
            Text(l10n.sheetCurvesEmpty, style: theme.textTheme.bodyLarge)
          else
            for (final series in sheet.series) ...[
              ExerciseCurveCard(
                series: series,
                title: StudentSheetView.exerciseTitle(
                  l10n,
                  sheet,
                  series.exercise,
                ),
                passesRequired: sheet.passesRequired,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}
