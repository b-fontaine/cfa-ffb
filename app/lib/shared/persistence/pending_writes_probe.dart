import 'dart:async';

import 'package:injectable/injectable.dart';

/// Ce que le **SDK** sait des écritures qu'il n'a pas encore pu envoyer
/// (ADR 0024, C4) : elles vivent dans le cache persistant et **survivent au
/// rechargement** de la page ou au redémarrage de l'application, alors que le
/// suivi en mémoire de `SendTracker` repart de zéro. La garde de déconnexion
/// et la pastille de synchronisation s'y fondent pour ne jamais annoncer
/// « À jour » à tort. L'implémentation de production est
/// `app/platform/firestore_pending_writes_probe.dart`.
abstract interface class PendingWritesProbe {
  /// Le SDK garde des écritures non envoyées. Réponse **courte** (délai
  /// borné) : une file qui ne se vide pas assez vite compte comme non vide ;
  /// un SDK injoignable (pas encore initialisé) répond `false`.
  Future<bool> hasPending();

  /// Se termine quand la file du SDK est vide, ou quand elle ne peut plus se
  /// vider (instance terminée) ; ne lève jamais.
  Future<void> untilSent();
}

/// Double en mémoire des tests et scénarios BDD : la file du « SDK » se
/// remplit et se vide à la demande.
@LazySingleton(as: PendingWritesProbe, env: [Environment.test])
class InMemoryPendingWritesProbe implements PendingWritesProbe {
  Completer<void>? _queue;

  /// Nombre de questions posées.
  int probes = 0;

  /// Le « SDK » garde une écriture (écrite avant un redémarrage, par exemple).
  void hold() => _queue ??= Completer<void>();

  /// Le serveur a tout acquitté.
  void flush() {
    _queue?.complete();
    _queue = null;
  }

  @override
  Future<bool> hasPending() async {
    probes++;
    return _queue != null;
  }

  @override
  Future<void> untilSent() => _queue?.future ?? Future<void>.value();
}
