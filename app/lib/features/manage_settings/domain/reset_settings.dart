import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : rétablir les valeurs par défaut (ADR 0003). Les passages
/// saisis ne sont pas touchés.
@injectable
class ResetSettings {
  ResetSettings(this._settings, this._store);

  final SettingsRepository _settings;
  final RulesStore _store;

  Future<Result<ClubSettings>> call() => runGuarded(() async {
    final rules = ClubSettings.defaults.applyTo(_store.current);
    await _settings.reset();
    _store.current = rules;
    return ClubSettings.defaults;
  });
}
