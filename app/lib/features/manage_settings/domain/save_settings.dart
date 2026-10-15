import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : enregistrer les réglages du club.
///
/// La configuration est validée par `RulesConfig` (`invalidRules`) avant la
/// moindre écriture ; la valeur courante des règles n'est remplacée qu'après
/// l'écriture. Aucun passage saisi n'est modifié.
@injectable
class SaveSettings {
  SaveSettings(this._settings, this._store);

  final SettingsRepository _settings;
  final RulesStore _store;

  Future<Result<ClubSettings>> call(ClubSettings settings) =>
      runGuarded(() async {
        final rules = settings.applyTo(_store.current);
        await _settings.save(settings);
        _store.current = rules;
        return settings;
      });
}
