import 'dart:async';

/// Recharge un écran à chaque changement de ses données partagées (FB5b).
///
/// Un cubit ou un bloc y confie son abonnement : `open` ouvre le flux de
/// changements (`changesOf` sur les `watch…` des dépôts), `reload` relit
/// l'écran **sans repasser par son état de chargement** (les données restent
/// affichées pendant la relecture). Les règles :
/// - **un seul abonnement** : `start` sur un écran déjà abonné ne fait rien,
///   `restart` remplace l'abonnement (un « Réessayer » après un refus rouvre
///   l'écoute fermée par l'erreur) ;
/// - **jamais deux relectures en parallèle** : les changements qui arrivent
///   pendant une relecture se fondent en **une** relecture de plus ;
/// - une **erreur** du flux déclenche aussi une relecture : elle reproduit
///   l'échec (accès refusé, réseau) par le chemin normal de l'écran, qui
///   l'affiche comme à un chargement ordinaire ;
/// - une erreur termine le flux (règle changée, portée changée) ; l'écran le
///   **rouvre** une fois la relecture qui suit achevée, qu'elle réussisse ou
///   échoue, pour que la lecture sous la nouvelle portée reste en temps réel.
///   Sans boucle : après une réouverture, une nouvelle erreur **sans donnée
///   entre-temps** (ouverture refusée) ne rouvre plus ; « Réessayer »
///   (`restart`) repart de zéro ;
/// - `stop` annule l'abonnement et empêche toute relecture ultérieure ;
///   l'écran l'appelle à sa fermeture.
final class LiveReload {
  LiveReload({required this.open, required this.reload});

  /// Ouvre le flux des changements.
  final Stream<void> Function() open;

  /// Relit l'écran.
  final Future<void> Function() reload;

  StreamSubscription<void>? _subscription;
  var _reloading = false;
  var _dirty = false;
  var _failedWithoutData = false;

  /// L'écran est abonné.
  bool get isActive => _subscription != null;

  /// S'abonne (sans effet si déjà abonné).
  void start() {
    if (_subscription != null) return;
    late final StreamSubscription<void> subscription;
    subscription = open().listen((_) {
      _failedWithoutData = false;
      unawaited(_pump());
    }, onError: (Object _, StackTrace _) => unawaited(_onError(subscription)));
    _subscription = subscription;
  }

  Future<void> _onError(StreamSubscription<void> subscription) async {
    final reopen = !_failedWithoutData;
    _failedWithoutData = true;
    await _pump();
    if (reopen && identical(_subscription, subscription)) _reopen();
  }

  /// Remplace l'abonnement par un neuf.
  void restart() {
    _failedWithoutData = false;
    _reopen();
  }

  void _reopen() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    start();
  }

  /// Se désabonne ; une relecture en cours se termine sans en entraîner une
  /// autre.
  Future<void> stop() async {
    _dirty = false;
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _pump() async {
    if (_reloading) {
      _dirty = true;
      return;
    }
    _reloading = true;
    try {
      do {
        _dirty = false;
        try {
          await reload();
        } on Object {
          // La relecture dit elle-même son échec à l'écran ; l'abonnement
          // continue.
        }
      } while (_dirty && _subscription != null);
    } finally {
      _reloading = false;
    }
  }
}
