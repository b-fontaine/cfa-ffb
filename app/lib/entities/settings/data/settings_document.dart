import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance réglages <-> document unique `clubs/{c}/settings/main`.
///
/// Champs : ceux de `settingsShape` dans `firestore.rules` (quatre entiers
/// obligatoires, `backupReminderDays` facultatif). Un champ absent prend sa
/// valeur par défaut ; un champ d'un autre type est une `ServiceFailure`.
/// Les **préférences d'appareil** (club retenu, etc.) n'y sont jamais : elles
/// restent dans le `KeyValueStore` de l'appareil.
abstract final class SettingsDocument {
  static Fields encode(ClubSettings settings) => {
    'passesRequired': settings.passesRequired,
    'alertThreshold': settings.alertThreshold,
    'recallStaleSessions': settings.recallStaleSessions,
    'groupFailureSharePercent': settings.groupFailureSharePercent,
    'backupReminderDays': settings.backupReminderDays,
  };

  static ClubSettings decode(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    final defaults = ClubSettings.defaults;
    return ClubSettings(
      passesRequired: values.integer(
        'passesRequired',
        fallback: defaults.passesRequired,
      ),
      alertThreshold: values.integer(
        'alertThreshold',
        fallback: defaults.alertThreshold,
      ),
      recallStaleSessions: values.integer(
        'recallStaleSessions',
        fallback: defaults.recallStaleSessions,
      ),
      groupFailureSharePercent: values.integer(
        'groupFailureSharePercent',
        fallback: defaults.groupFailureSharePercent,
      ),
      backupReminderDays: values.integer(
        'backupReminderDays',
        fallback: defaults.backupReminderDays,
      ),
    );
  }
}
