import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/features/suggest_session/domain/exercise_sheet.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Fiche d'un exercice : numéro de fiche technique fédérale, taux requis,
/// pont, mention et consigne (données du catalogue, source de rang 1).
class ExerciseSheetView extends StatelessWidget {
  const ExerciseSheetView({required this.sheet, super.key});

  final ExerciseSheet sheet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spec = sheet.spec;
    final block = sheet.block;
    final note = spec.note;
    return SectionCard(
      title: l10n.sheetExerciseTitle(block.title, spec.ref.number),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.exerciseSheetNumbers(block.technicalSheets.join(', ')),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.exerciseRequired(spec.rate.successes, spec.rate.attempts),
            style: theme.textTheme.bodyLarge,
          ),
          if (spec.bridge != null)
            Text(
              spec.bridge == Bridge.frame
                  ? l10n.exerciseBridgeFrame
                  : l10n.exerciseBridgeSurface,
            ),
          if (note != null) Text(l10n.exerciseNote(note)),
          Text(
            l10n.exerciseRecommended(
              block.recommendedSessions.min,
              block.recommendedSessions.max,
            ),
          ),
          if (spec.bronze) ...[
            const SizedBox(height: AppSpacing.sm),
            StatusBadge(tone: BadgeTone.neutral, label: l10n.exerciseBronze),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(l10n.exerciseSource, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
