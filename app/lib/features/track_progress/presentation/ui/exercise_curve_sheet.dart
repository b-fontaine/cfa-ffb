import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/exercise_curve_card.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Contenu de la feuille basse ouverte au toucher d'une case du parcours : la
/// courbe de l'exercice avec son alternative textuelle, ou « Pas encore
/// pratiqué ». [title] est le titre localisé de l'exercice.
class ExerciseCurveSheet extends StatelessWidget {
  const ExerciseCurveSheet({
    required this.sheet,
    required this.exercise,
    required this.title,
    required this.onClose,
    super.key,
  });

  final StudentSheet sheet;
  final ExerciseRef exercise;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final series = sheet.series
        .where((s) => s.exercise == exercise)
        .firstOrNull;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (series == null) ...[
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.sheetCellNotPractised,
                style: theme.textTheme.bodyLarge,
              ),
            ] else
              ExerciseCurveCard(
                series: series,
                title: title,
                passesRequired: sheet.passesRequired,
              ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onClose,
                child: Text(l10n.sheetCurveSheetClose),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ouvre la feuille basse de la courbe de [exercise].
Future<void> showExerciseCurveSheet(
  BuildContext context, {
  required StudentSheet sheet,
  required ExerciseRef exercise,
  required String title,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheetContext) => ExerciseCurveSheet(
    sheet: sheet,
    exercise: exercise,
    title: title,
    onClose: () => Navigator.of(sheetContext).pop(),
  ),
);
