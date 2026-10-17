/// Frontière du SDK Firebase : tout ce que l'application lui demande au
/// démarrage. Les tests en fournissent une fausse ; l'implémentation réelle est
/// `platform/firebase_sdk_gateway.dart`.
abstract interface class FirebaseGateway {
  /// Initialise l'application Firebase par défaut.
  Future<void> initialize();

  /// Redirige Auth et Firestore vers les émulateurs. À appeler après
  /// [initialize] et avant tout usage de ces services.
  Future<void> useEmulators({
    required String host,
    required int authPort,
    required int firestorePort,
  });
}
