import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_result.freezed.dart';

/// Avancement d'un élève sur un exercice.
enum ExerciseStatus { notStarted, inProgress, validated }

/// Niveau d'alerte après échecs consécutifs (R4).
enum AlertLevel { none, attention, persistent }

/// Vue dérivée (jamais saisie) des passages d'un élève sur un exercice.
@freezed
abstract class ExerciseResult with _$ExerciseResult {
  const factory ExerciseResult({
    required StudentId studentId,
    required ExerciseRef exercise,
    required SuccessRate rate,
    required List<ExerciseAttempt> attempts,
    required int passedCount,
    required ExerciseStatus status,
    required DateTime? validatedOn,
    required int consecutiveFailures,
    required AlertLevel alert,
  }) = _ExerciseResult;

  const ExerciseResult._();

  /// Dérive le résultat. [attempts] concerne uniquement cet élève et cet
  /// exercice ; ils sont triés par (date, `passIndex`).
  ///
  /// R1/R2 : validé après `passesRequired` passages réussis (cumulés, pas
  /// forcément consécutifs) ; la validation est monotone. R4 : les échecs
  /// consécutifs sont ceux qui suivent la dernière réussite.
  factory ExerciseResult.derive({
    required StudentId studentId,
    required ExerciseRef exercise,
    required SuccessRate rate,
    required List<ExerciseAttempt> attempts,
    required RulesConfig config,
  }) {
    final sorted = [...attempts]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.passIndex.compareTo(b.passIndex);
      });
    var passed = 0;
    var failures = 0;
    DateTime? validatedOn;
    for (final attempt in sorted) {
      if (attempt.isPassed(rate)) {
        passed++;
        failures = 0;
        if (passed == config.passesRequired) validatedOn = attempt.date;
      } else {
        failures++;
      }
    }
    final validated = passed >= config.passesRequired;
    final status = validated
        ? ExerciseStatus.validated
        : sorted.isEmpty
        ? ExerciseStatus.notStarted
        : ExerciseStatus.inProgress;
    return ExerciseResult(
      studentId: studentId,
      exercise: exercise,
      rate: rate,
      attempts: List.unmodifiable(sorted),
      passedCount: passed,
      status: status,
      validatedOn: validatedOn,
      consecutiveFailures: failures,
      alert: validated
          ? AlertLevel.none
          : failures >= config.persistentAlertThreshold
          ? AlertLevel.persistent
          : failures >= config.alertThreshold
          ? AlertLevel.attention
          : AlertLevel.none,
    );
  }

  bool get isValidated => status == ExerciseStatus.validated;

  bool get hasActiveAlert => alert != AlertLevel.none;

  ExerciseAttempt? get lastAttempt => attempts.lastOrNull;

  /// Vrai si le dernier passage n'a pas atteint le taux requis.
  bool get lastFailed {
    final last = lastAttempt;
    return last != null && !last.isPassed(rate);
  }

  /// Dernier résultat rapporté au taux requis (1 = taux atteint).
  double? get lastRelativeScore {
    final last = lastAttempt;
    return last == null
        ? null
        : rate.relativeScore(potted: last.potted, total: last.total);
  }
}
