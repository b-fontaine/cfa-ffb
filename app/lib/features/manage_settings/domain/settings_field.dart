import 'package:billard_cfa/entities/settings/domain/club_settings.dart';

/// Un réglage que l'animateur peut modifier, avec ses bornes d'écran.
///
/// Les bornes sont un sous-ensemble de celles de `RulesConfig` (qui reste la
/// seule validation) : l'écran ne peut produire que des configurations
/// valides. [step] est le pas d'un appui (la valeur est ramenée à la borne).
enum SettingsField {
  passesRequired(min: 1, max: 10),
  alertThreshold(min: 1, max: 5),
  recallStaleSessions(min: 1, max: 12),
  groupFailureSharePercent(min: 10, max: 100, step: 10),
  backupReminderDays(min: 7, max: 90, step: 5);

  SettingsField({required this.min, required this.max, this.step = 1});

  final int min;
  final int max;
  final int step;

  int read(ClubSettings settings) => switch (this) {
    passesRequired => settings.passesRequired,
    alertThreshold => settings.alertThreshold,
    recallStaleSessions => settings.recallStaleSessions,
    groupFailureSharePercent => settings.groupFailureSharePercent,
    backupReminderDays => settings.backupReminderDays,
  };

  /// [settings] dont ce réglage vaut [value] (non borné : voir `applyTo`).
  ClubSettings write(ClubSettings settings, int value) => switch (this) {
    passesRequired => settings.copyWith(passesRequired: value),
    alertThreshold => settings.copyWith(alertThreshold: value),
    recallStaleSessions => settings.copyWith(recallStaleSessions: value),
    groupFailureSharePercent => settings.copyWith(
      groupFailureSharePercent: value,
    ),
    backupReminderDays => settings.copyWith(backupReminderDays: value),
  };
}
