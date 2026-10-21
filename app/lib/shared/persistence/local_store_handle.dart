import 'package:drift/drift.dart';

/// Une base locale **ouverte pour la lecture** par la détection (lot FB7c),
/// et ce qu'il faut libérer quand elle a fini.
///
/// [privateConnection] : la connexion n'appartient qu'à la détection (fichier
/// natif en lecture seule, base IndexedDB lue dans la page). Elle seule peut
/// recevoir `PRAGMA query_only` ; une connexion **partagée** avec
/// l'application (serveur d'un worker de drift) n'en reçoit jamais, sous peine
/// de rendre l'application elle-même muette en écriture.
class LocalStoreHandle {
  LocalStoreHandle(
    this.executor, {
    this.privateConnection = true,
    this.onRelease,
  });

  final QueryExecutor executor;
  final bool privateConnection;
  final Future<void> Function()? onRelease;
  bool _released = false;

  /// Ferme l'exécuteur puis libère le reste (verrou, connexion IndexedDB).
  /// Idempotent, et sans jamais lever : la base n'a pas été modifiée, un échec
  /// de fermeture n'y change rien.
  Future<void> release() async {
    if (_released) return;
    _released = true;
    try {
      await executor.close();
    } on Object {
      // Voir ci-dessus.
    }
    try {
      await onRelease?.call();
    } on Object {
      // Voir ci-dessus.
    }
  }
}
