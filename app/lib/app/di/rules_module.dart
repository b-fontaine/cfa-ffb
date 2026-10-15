import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:injectable/injectable.dart';

/// Câblage de la valeur courante des règles (ADR 0012).
///
/// `RulesConfig` n'est pas un singleton : chaque cas d'usage créé reçoit la
/// valeur courante du [RulesStore]. Ne jamais l'injecter dans un singleton.
@module
abstract class RulesModule {
  /// Chargé au lancement depuis les réglages persistés ; des réglages
  /// persistés refusés par `RulesConfig` laissent les valeurs par défaut.
  @preResolve
  @singleton
  Future<RulesStore> rulesStore(SettingsRepository settings) async {
    final base = RulesConfig();
    final stored = (await settings.load()).orDefaults(base);
    return RulesStore(stored.applyTo(base));
  }

  @injectable
  RulesConfig rulesConfig(RulesStore store) => store.current;
}
