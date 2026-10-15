import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : lire les réglages du club (valeurs par défaut si rien n'est
/// enregistré ou si la valeur enregistrée est refusée par les règles).
@injectable
class LoadSettings {
  LoadSettings(this._settings, this._store);

  final SettingsRepository _settings;
  final RulesStore _store;

  Future<Result<ClubSettings>> call() => runGuarded(
    () async => (await _settings.load()).orDefaults(_store.current),
  );
}
