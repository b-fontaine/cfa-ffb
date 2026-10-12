import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_curve.freezed.dart';

/// Un point de la courbe : un passage, dans l'ordre chronologique (1..n).
@freezed
abstract class CurvePoint with _$CurvePoint {
  const factory CurvePoint({
    required int index,
    required DateTime date,
    required SessionId sessionId,
    required int potted,
    required int total,
    required bool passed,
  }) = _CurvePoint;

  const CurvePoint._();

  double get ratio => potted / total;
}

/// Courbe de progression d'un élève sur un exercice et ses métriques dérivées.
@freezed
abstract class ExerciseCurve with _$ExerciseCurve {
  const factory ExerciseCurve({
    required List<CurvePoint> points,
    required CurvePoint? best,
    required double? delta,
    required List<double> movingAverage,
    required double? slope,
    required double? relativeScore,
    required int? passesToValidation,
    required int? sessionsToValidation,
    required bool stagnating,
  }) = _ExerciseCurve;

  const ExerciseCurve._();

  /// Calcule la courbe d'un [result] : meilleur passage, écart dernier -
  /// premier, moyenne mobile (`movingAverageWindow`), pente de régression des
  /// `trendWindow` derniers ratios, score relatif, passages et séances
  /// jusqu'à la validation, stagnation.
  factory ExerciseCurve.of(ExerciseResult result, RulesConfig config) {
    final points = [
      for (var i = 0; i < result.attempts.length; i++)
        CurvePoint(
          index: i + 1,
          date: result.attempts[i].date,
          sessionId: result.attempts[i].sessionId,
          potted: result.attempts[i].potted,
          total: result.attempts[i].total,
          passed: result.attempts[i].isPassed(result.rate),
        ),
    ];
    final ratios = [for (final point in points) point.ratio];
    final window = config.movingAverageWindow;
    var passed = 0;
    int? validationIndex;
    for (final point in points) {
      if (point.passed) passed++;
      if (passed == config.passesRequired && validationIndex == null) {
        validationIndex = point.index;
      }
    }
    final recent = ratios.length > config.trendWindow
        ? ratios.sublist(ratios.length - config.trendWindow)
        : ratios;
    final slope = _slope(recent);
    return ExerciseCurve(
      points: List.unmodifiable(points),
      best: points.isEmpty
          ? null
          : points.reduce((a, b) => b.ratio > a.ratio ? b : a),
      delta: points.isEmpty ? null : ratios.last - ratios.first,
      movingAverage: [
        for (var i = 0; i + window <= ratios.length; i++)
          ratios.sublist(i, i + window).reduce((a, b) => a + b) / window,
      ],
      slope: slope,
      relativeScore: result.lastRelativeScore,
      passesToValidation: validationIndex,
      sessionsToValidation: validationIndex == null
          ? null
          : points
                .take(validationIndex)
                .map((point) => point.sessionId)
                .toSet()
                .length,
      stagnating:
          !result.isValidated &&
          points.length >= config.stagnationPasses &&
          slope != null &&
          slope <= 0,
    );
  }
}

/// Pente de la régression linéaire de [ys] (ordre chronologique, abscisses
/// 0..n-1) ; `null` avec moins de deux points.
///
/// Comme la somme des écarts à la moyenne des abscisses est nulle, la
/// covariance se réduit à `sum((x - moyenne) * y)` et la variance des abscisses
/// vaut `n * (n² - 1) / 12`.
double? _slope(List<double> ys) {
  if (ys.length < 2) return null;
  final n = ys.length;
  final meanX = (n - 1) / 2;
  var covariance = 0.0;
  for (var x = 0; x < n; x++) {
    covariance += (x - meanX) * ys[x];
  }
  return covariance * 12 / (n * (n * n - 1));
}
