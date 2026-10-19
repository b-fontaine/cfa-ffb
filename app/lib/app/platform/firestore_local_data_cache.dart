import 'dart:async';

import 'package:billard_cfa/shared/persistence/local_data_cache.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Le cache local de Firestore, effacé par le SDK : l'instance est
/// **terminée** (condition de `clearPersistence`, qui échoue sinon), puis son
/// stockage abandonné. `clearPersistence` ne réécrit pas le disque (le SDK le
/// dit) ; les données ne sont plus lisibles par l'application.
///
/// **Plusieurs onglets** (web) : `clearPersistence` supprime la base IndexedDB
/// que les autres onglets tiennent ouverte ; la suppression peut rester
/// bloquée tant qu'ils ne se ferment pas. L'effacement est donc **borné par un
/// délai** et échoue (`TimeoutException`) au-delà : `LocalDataGuard.release`
/// laisse alors le propriétaire consigné, la déconnexion se termine.
///
/// **Natif** : après `terminate`, le plugin recrée l'instance native au
/// prochain appel à partir des réglages gardés côté Dart ; [reopen] les
/// **réapplique**
/// (sans changer leur valeur : l'hôte d'un émulateur reste) pour ne pas
/// dépendre de ce détail du plugin. Ce chemin n'est pas exercé par un test
/// d'intégration natif (aucun appareil dans les garde-fous) : voir
/// `hors-ligne-plan.md`.
///
/// Les appels au SDK sont injectables : les tests n'atteignent jamais le SDK.
class FirestoreLocalDataCache implements LocalDataCache {
  FirestoreLocalDataCache({
    required this._reload,
    Future<void> Function()? terminate,
    Future<void> Function()? clearPersistence,
    void Function()? reapplySettings,
    this.clearTimeout = const Duration(seconds: 5),
    bool? native,
  }) : _terminate = terminate ?? (() => FirebaseFirestore.instance.terminate()),
       _clearPersistence =
           clearPersistence ??
           (() => FirebaseFirestore.instance.clearPersistence()),
       _reapplySettings =
           reapplySettings ??
           (() {
             final firestore = FirebaseFirestore.instance;
             final current = firestore.settings;
             firestore.settings = current;
           }),
       _native = native ?? !kIsWeb;

  final Future<void> Function() _reload;
  final Future<void> Function() _terminate;
  final Future<void> Function() _clearPersistence;
  final void Function() _reapplySettings;
  final bool _native;

  /// Délai de l'effacement (autre onglet qui tient la base).
  final Duration clearTimeout;

  @override
  Future<void> clear() async {
    await _terminate();
    await _clearPersistence().timeout(clearTimeout);
  }

  @override
  Future<void> reopen() {
    if (_native) _reapplySettings();
    return _reload();
  }
}
