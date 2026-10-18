import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : aligner les règles courantes (`RulesStore`) sur les
/// **réglages du club actif** (ADR 0012, ADR 0024 A5 et A11).
///
/// Appelé à l'activation d'un club et à la bascule de club (`AuthCubit`),
/// jamais avant l'ouverture de session : avec Firestore, les réglages sont un
/// document **par club**, illisible tant qu'aucun club n'est actif. Seuls les
/// réglages du club sont lus ; les préférences d'appareil (club retenu, etc.)
/// vivent dans le `KeyValueStore` local et ne passent pas ici.
///
/// Part toujours des règles **de base** (`RulesStore.base`, les valeurs par
/// défaut), jamais de la valeur courante : le club suivant ne reprend rien du
/// précédent. Des réglages illisibles
/// (réseau, refus du serveur) ou refusés par `RulesConfig` laissent les
/// valeurs par défaut : l'application s'ouvre quand même.
@injectable
class ReloadRules {
  ReloadRules(this._settings, this._store);

  final SettingsRepository _settings;
  final RulesStore _store;

  /// Charge les réglages du club actif. Ne lève jamais : l'échec de lecture est
  /// rendu, les règles sont alors celles par défaut.
  ///
  /// La lecture est lente (réseau) : [isCurrent] dit, **à la fin**, si ce
  /// chargement est toujours d'actualité (le club n'a pas changé, la session
  /// n'est pas fermée). Sinon rien n'est écrit : un chargement tardif ne
  /// réinstalle ni les règles d'un club quitté, ni celles d'une session
  /// terminée.
  Future<Result<void>> call({bool Function()? isCurrent}) async {
    final base = _store.base;
    bool current() => isCurrent?.call() ?? true;
    final result = await runGuarded(() async {
      final stored = (await _settings.load()).orDefaults(base);
      if (current()) _store.current = stored.applyTo(base);
    });
    if (result is Err<void> && current()) _store.current = base;
    return result;
  }

  /// Oublie les règles du club (déconnexion, aucun club actif).
  void reset() => _store.current = _store.base;
}
