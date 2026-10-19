import 'package:injectable/injectable.dart';

/// Le **cache local** des données du club (cache hors ligne de Firestore :
/// documents lus et écritures pas encore envoyées), qui reste sur l'appareil
/// quand personne n'est connecté (ADR 0024, décision 1 et C4).
///
/// Il contient des données d'élèves mineurs : il est **vidé à la déconnexion**
/// et quand un **autre compte** se connecte sur le même appareil
/// (`LocalDataGuard`). L'implémentation de production est
/// `app/platform/firestore_local_data_cache.dart` ; le SDK ne promet pas de
/// réécrire le disque (`clearPersistence` abandonne le stockage, sans l'écraser
/// : le registre de conformité le dit).
abstract interface class LocalDataCache {
  /// Efface le cache, **écritures non envoyées comprises** (l'appelant s'est
  /// assuré de ne rien perdre). Après un effacement, le stock de documents ne
  /// doit plus servir avant [reopen].
  Future<void> clear();

  /// Remet le stock de documents en service après [clear] : sur le web, la page
  /// est rechargée (le SDK ne rouvre pas une instance terminée) ; ailleurs, le
  /// SDK recrée l'instance au prochain appel.
  Future<void> reopen();
}

/// Double en mémoire des tests et scénarios BDD : consigne les appels.
@LazySingleton(as: LocalDataCache, env: [Environment.test])
class InMemoryLocalDataCache implements LocalDataCache {
  /// Nombre d'effacements demandés.
  int clears = 0;

  /// Nombre de remises en service demandées.
  int reopens = 0;

  /// Fait échouer chaque effacement (disque indisponible, autre onglet).
  Exception? clearFailure;

  @override
  Future<void> clear() async {
    final failure = clearFailure;
    if (failure != null) throw failure;
    clears++;
  }

  @override
  Future<void> reopen() async => reopens++;
}
