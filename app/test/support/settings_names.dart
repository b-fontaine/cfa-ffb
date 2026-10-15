import 'package:billard_cfa/entities/settings/domain/club_settings.dart';

/// Vocabulaire des scénarios de réglages : nom français -> clé du fichier de
/// sauvegarde et accès au réglage.
class SettingsNames {
  const SettingsNames._();

  static const _keys = {
    'passages requis': 'passesRequired',
    'seuil alerte': 'alertThreshold',
    'séances avant rappel': 'recallStaleSessions',
    'part échec groupe': 'groupFailureSharePercent',
    'délai rappel sauvegarde': 'backupReminderDays',
  };

  /// Clé JSON du réglage [name].
  static String key(String name) =>
      _keys[name] ?? (throw ArgumentError('réglage inconnu : $name'));

  static int read(ClubSettings settings, String name) => switch (key(name)) {
    'passesRequired' => settings.passesRequired,
    'alertThreshold' => settings.alertThreshold,
    'recallStaleSessions' => settings.recallStaleSessions,
    'groupFailureSharePercent' => settings.groupFailureSharePercent,
    _ => settings.backupReminderDays,
  };

  static ClubSettings write(ClubSettings settings, String name, int value) =>
      switch (key(name)) {
        'passesRequired' => settings.copyWith(passesRequired: value),
        'alertThreshold' => settings.copyWith(alertThreshold: value),
        'recallStaleSessions' => settings.copyWith(recallStaleSessions: value),
        'groupFailureSharePercent' => settings.copyWith(
          groupFailureSharePercent: value,
        ),
        _ => settings.copyWith(backupReminderDays: value),
      };
}
