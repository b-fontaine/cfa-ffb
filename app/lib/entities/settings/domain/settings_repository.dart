import 'package:billard_cfa/entities/settings/domain/club_settings.dart';

/// Port de persistance des réglages du club (implémenté dans la couche data).
///
/// Ne valide rien : la validation est celle de `RulesConfig`
/// (`ClubSettings.applyTo`), faite par les cas d'usage avant d'écrire.
abstract interface class SettingsRepository {
  /// Réglages enregistrés ; les valeurs par défaut si rien n'est enregistré.
  Future<ClubSettings> load();

  /// Remplace les réglages enregistrés.
  Future<void> save(ClubSettings settings);

  /// Oublie les réglages enregistrés (retour aux valeurs par défaut).
  Future<void> reset();
}
