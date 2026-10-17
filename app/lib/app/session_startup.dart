import 'package:injectable/injectable.dart';

/// Ce que `AuthCubit` attend avant de lire la session : le SDK
/// d'authentification est-il prêt ? Production : `FirebaseStartup` ; tests :
/// [InMemorySessionStartup].
abstract interface class SessionStartup {
  /// `true` si le service est prêt, `false` s'il est indisponible. Ne lève
  /// jamais.
  Future<bool> get ready;

  /// Retente une initialisation qui a échoué (bouton « Réessayer »).
  Future<bool> retry();
}

/// Démarrage des tests et scénarios BDD : prêt, ou indisponible à la demande.
@LazySingleton(as: SessionStartup, env: [Environment.test])
class InMemorySessionStartup implements SessionStartup {
  /// Quand il est faux, le service est indisponible.
  bool available = true;

  @override
  Future<bool> get ready async => available;

  @override
  Future<bool> retry() async => available;
}
