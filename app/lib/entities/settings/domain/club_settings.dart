import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'club_settings.freezed.dart';

/// Réglages que l'animateur peut modifier (ADR 0012).
///
/// Aucune validation propre : les bornes et les défauts sont ceux de
/// `RulesConfig` ([applyTo] laisse son constructeur trancher).
@freezed
abstract class ClubSettings with _$ClubSettings {
  const factory ClubSettings({
    required int passesRequired,
    required int alertThreshold,
    required int recallStaleSessions,
    required int groupFailureSharePercent,
    required int backupReminderDays,
  }) = _ClubSettings;

  const ClubSettings._();

  /// Les réglages d'une configuration de règles.
  factory ClubSettings.fromRules(RulesConfig rules) => ClubSettings(
    passesRequired: rules.passesRequired,
    alertThreshold: rules.alertThreshold,
    recallStaleSessions: rules.recallStaleSessions,
    groupFailureSharePercent: rules.groupFailureSharePercent,
    backupReminderDays: rules.backupReminderDays,
  );

  /// Valeurs par défaut (ADR 0003).
  static final defaults = ClubSettings.fromRules(RulesConfig());

  /// [base] dont les paramètres réglables sont remplacés par ceux-ci.
  ///
  /// Lève `InvariantViolation(invalidRules)` si la configuration obtenue est
  /// refusée par `RulesConfig`.
  RulesConfig applyTo(RulesConfig base) => base.copyWith(
    passesRequired: passesRequired,
    alertThreshold: alertThreshold,
    recallStaleSessions: recallStaleSessions,
    groupFailureSharePercent: groupFailureSharePercent,
    backupReminderDays: backupReminderDays,
  );

  /// Ces réglages s'ils sont applicables à [base], sinon les valeurs par
  /// défaut : une valeur persistée corrompue ne doit pas empêcher de démarrer.
  ClubSettings orDefaults(RulesConfig base) {
    try {
      applyTo(base);
      return this;
    } on InvariantViolation {
      return defaults;
    }
  }
}
