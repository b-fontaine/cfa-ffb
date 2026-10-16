/// Port de la mise à jour de l'application (lot 15) : « une nouvelle version
/// attend-elle d'être activée ? ». Dart pur ; les implémentations (service
/// worker du navigateur, aucune sur mobile) sont dans la couche `app`.
///
/// Une nouvelle version n'est jamais activée d'office : la page ouverte garde
/// ses fichiers, la saisie en cours n'est pas interrompue. L'activation
/// ([apply]) est demandée par l'utilisateur.
abstract interface class AppUpdateSource {
  /// Vrai quand une version plus récente est installée et attend.
  bool get isAvailable;

  /// Vrai/faux à chaque changement de [isAvailable].
  Stream<bool> get changes;

  /// Active la version en attente et recharge l'application. Sans version en
  /// attente, recharge simplement.
  Future<void> apply();
}
