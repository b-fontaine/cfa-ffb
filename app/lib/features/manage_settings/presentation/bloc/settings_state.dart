part of 'settings_bloc.dart';

enum SettingsStatus {
  /// Lecture des réglages en cours.
  loading,

  /// Formulaire affiché (brouillon modifié ou non).
  editing,
  saving,

  /// Réglages enregistrés (message d'état persistant).
  saved,

  /// Valeurs par défaut rétablies.
  reset,

  /// Enregistrement refusé ou lecture impossible ; le brouillon est conservé.
  failed,
}

@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(SettingsStatus.loading) SettingsStatus status,

    /// Valeurs enregistrées ; `null` tant qu'elles ne sont pas lues.
    ClubSettings? saved,

    /// Valeurs du formulaire.
    ClubSettings? draft,
    Failure? failure,
  }) = _SettingsState;

  const SettingsState._();

  /// Le formulaire diffère des valeurs enregistrées.
  bool get isDirty => draft != null && draft != saved;
}
