import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:injectable/injectable.dart';

/// Câblage de la valeur courante des règles (ADR 0012).
///
/// `RulesConfig` n'est pas un singleton : chaque cas d'usage créé reçoit la
/// valeur courante du [RulesStore]. Ne jamais l'injecter dans un singleton.
@module
abstract class RulesModule {
  /// Chargé au lancement depuis les réglages persistés (drift : l'appareil,
  /// sans club) ; des réglages persistés refusés par `RulesConfig`, ou
  /// illisibles,
  /// laissent les valeurs par défaut. Avec Firestore, les réglages sont ceux
  /// d'un **club** : aucun n'est actif au lancement (accès refusé) : le
  /// démarrage garde les valeurs par défaut, et `ReloadRules` charge ceux du
  /// club à son activation (`AuthCubit`, ADR 0024, notes FB4c).
  @preResolve
  @singleton
  Future<RulesStore> rulesStore(SettingsRepository settings) async {
    final base = RulesConfig();
    try {
      final stored = (await settings.load()).orDefaults(base);
      return RulesStore(stored.applyTo(base), base: base);
    } on Failure {
      return RulesStore(base);
    }
  }

  @injectable
  RulesConfig rulesConfig(RulesStore store) => store.current;
}
