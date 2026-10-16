import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/default_session_shapes.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rules_config.freezed.dart';

/// Seuils et paramètres des règles : de la configuration, jamais des
/// constantes cachées dans les règles (ADR 0003).
///
/// La valeur courante vient de `RulesStore` (ADR 0012) : ne pas conserver une
/// instance à travers un changement de réglage ; ne jamais l'injecter dans un
/// singleton.
@freezed
abstract class RulesConfig with _$RulesConfig {
  /// Configuration validée. Les valeurs par défaut sont celles de l'ADR 0003.
  factory RulesConfig({
    @Default(5) int passesRequired,
    @Default(3) int alertThreshold,
    @Default(5) int persistentAlertThreshold,
    @Default(4) int recallStaleSessions,
    @Default(50) int groupFailureSharePercent,

    /// Élèves en échec au minimum pour une alerte de groupe (en dessous, c'est
    /// une alerte individuelle). Non exposé à l'écran Réglages : ni persisté ni
    /// sauvegardé, il reprend toujours la valeur par défaut (ADR 0013).
    @Default(2) int minGroupFailures,
    @Default(5) int trendWindow,
    @Default(3) int movingAverageWindow,
    @Default(5) int stagnationPasses,
    @Default(2) int maxPassesPerExercisePerSession,
    @Default(2) int minDistinctExercises,
    @Default(3) int readinessMinScore,
    @Default(30) int backupReminderDays,
    @Default(defaultSessionShapes) Map<Audience, SessionShape> shapes,
  }) = _RulesConfig;

  /// Configuration par défaut (ADR 0003).
  factory RulesConfig.standard() => RulesConfig();

  RulesConfig._() {
    final positives = [
      passesRequired,
      alertThreshold,
      minGroupFailures,
      recallStaleSessions,
      trendWindow,
      movingAverageWindow,
      stagnationPasses,
      maxPassesPerExercisePerSession,
      minDistinctExercises,
    ];
    final valid =
        positives.every((value) => value >= 1) &&
        persistentAlertThreshold >= alertThreshold &&
        groupFailureSharePercent >= 1 &&
        groupFailureSharePercent <= 100 &&
        readinessMinScore >= 1 &&
        readinessMinScore <= 4 &&
        backupReminderDays >= 1 &&
        backupReminderDays <= 365 &&
        trendWindow >= 2 &&
        Audience.values.every(
          (audience) =>
              shapes[audience]?.isValidFor(audience, minDistinctExercises) ??
              false,
        );
    if (!valid) {
      throw const InvariantViolation(InvariantCode.invalidRules);
    }
  }
}
