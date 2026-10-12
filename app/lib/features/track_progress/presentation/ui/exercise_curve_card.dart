import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/features/track_progress/domain/exercise_curve.dart';
import 'package:billard_cfa/features/track_progress/domain/student_sheet.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/progress_chart.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Courbe de performance d'un exercice (essais en abscisse, billes
/// empochées en ordonnée) avec son alternative textuelle : meilleur résultat,
/// tendance et liste des essais.
class ExerciseCurveCard extends StatelessWidget {
  const ExerciseCurveCard({
    required this.series,
    required this.title,
    required this.passesRequired,
    super.key,
  });

  final ExerciseSeries series;

  /// Titre localisé de l'exercice (ex. « La puissance · exercice 1 »).
  final String title;
  final int passesRequired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final curve = series.curve;
    final best = curve.best;
    final slope = curve.slope;
    final trend = slope == null
        ? null
        : slope > 0
        ? l10n.sheetTrendUp
        : slope < 0
        ? l10n.sheetTrendDown
        : l10n.sheetTrendFlat;
    final (statusTone, statusLabel) = switch (series.status) {
      ExerciseStatus.validated => (BadgeTone.success, l10n.statusValidated),
      ExerciseStatus.inProgress => (BadgeTone.neutral, l10n.statusInProgress),
      ExerciseStatus.notStarted => (BadgeTone.neutral, l10n.statusNotStarted),
    };
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(tone: statusTone, label: statusLabel),
              if (series.alert != AlertLevel.none)
                StatusBadge(
                  tone: BadgeTone.attention,
                  label: l10n.sheetFailuresInARow(series.consecutiveFailures),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.sheetRequired(series.rate.successes, series.rate.attempts),
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            l10n.sheetPasses(series.passedCount, passesRequired),
            style: theme.textTheme.bodyMedium,
          ),
          if (best != null)
            Text(
              l10n.sheetBest(best.potted, best.total),
              style: theme.textTheme.bodyMedium,
            ),
          if (trend != null) Text(trend, style: theme.textTheme.bodyMedium),
          if (curve.stagnating)
            Text(l10n.sheetStagnating, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          ProgressChart(
            key: ValueKey(
              'curve-${series.exercise.blockId}-${series.exercise.number}',
            ),
            points: [
              for (final point in curve.points)
                ChartPoint(value: point.potted, reached: point.passed),
            ],
            maxValue: _axisMax(curve.points),
            target: series.rate.successes,
            semanticLabel: l10n.chartSemantics(
              curve.points.length,
              series.rate.successes,
              series.rate.attempts,
            ),
            axisLabelX: l10n.chartAxisX,
            axisLabelY: l10n.chartAxisY,
            targetLabel: l10n.chartTargetLine(series.rate.successes),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final point in curve.points) _AttemptRow(point: point),
        ],
      ),
    );
  }

  /// L'axe couvre les tentatives du catalogue et le plus grand total saisi.
  int _axisMax(List<CurvePoint> points) {
    var max = series.rate.attempts;
    for (final point in points) {
      if (point.total > max) max = point.total;
    }
    return max;
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.point});

  final CurvePoint point;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              point.passed ? Icons.check_circle : Icons.cancel_outlined,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              l10n.sheetAttemptRow(point.index, point.potted, point.total),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(point.passed ? l10n.sheetPassMet : l10n.sheetPassMissed),
        ],
      ),
    );
  }
}
