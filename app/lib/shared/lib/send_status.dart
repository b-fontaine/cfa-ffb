/// État de l'**envoi** des écritures vers le serveur (ADR 0024, décisions 1 et
/// 19 ; hors ligne, C4) : un lot est d'abord **validé localement** (le SDK
/// Firestore l'applique à son cache dès l'appel), puis envoyé ; le serveur ne
/// l'acquitte que lorsqu'il répond, parfois bien plus tard (hors ligne). Le
/// lot validé n'attend donc pas ce port : l'interface (FB5, pastille « Envoi
/// en attente ») le lit. Port de lecture sans Firestore (la pastille de
/// synchronisation et la garde de déconnexion le lisent) ; l'implémentation est
/// `shared/persistence/send_status.dart`.
abstract interface class SendStatus {
  /// Lots validés localement et pas encore acquittés par le serveur.
  int get pending;

  /// Le SDK garde des écritures non envoyées, **y compris celles d'une vie
  /// précédente de la page** (le compteur [pending] les ignore) : la garde de
  /// déconnexion s'y fie, pas à [pending] seul.
  Future<bool> hasUnsentWrites();

  /// Interroge le SDK sur sa file persistante (au lancement, quand le réseau
  /// change) : les écritures d'une vie précédente deviennent un lot en
  /// attente, donc visibles par la pastille.
  Future<void> refresh();

  /// Émet le nombre de lots en attente à chaque changement.
  Stream<int> get pendingChanges;

  /// Un envoi a été refusé par le serveur (règles, quota) et pas encore
  /// acquitté par l'animateur. Le SDK a alors annulé la modification de son
  /// cache : l'interface doit le dire (détail : `SendTracker.lastFailure`).
  bool get hasFailure;

  /// Oublie l'échec (l'animateur en a pris connaissance).
  void clearFailure();
}
