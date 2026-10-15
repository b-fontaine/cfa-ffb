part of 'settings_bloc.dart';

@freezed
sealed class SettingsEvent with _$SettingsEvent {
  const factory SettingsEvent.started() = SettingsStarted;

  /// Un compteur a changé : le brouillon est modifié, rien n'est écrit.
  const factory SettingsEvent.changed({
    required SettingsField field,
    required int value,
  }) = SettingsChanged;

  const factory SettingsEvent.saveRequested() = SettingsSaveRequested;

  /// L'animateur a confirmé le retour aux valeurs par défaut.
  const factory SettingsEvent.resetConfirmed() = SettingsResetConfirmed;
}
