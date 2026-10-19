import 'dart:async';

/// Un flux de **changements** : un événement chaque fois qu'une des [sources]
/// change, rien d'autre.
///
/// Chaque source est un flux d'états (`watch…` d'un dépôt) dont le **premier**
/// état est l'état de départ, pas un changement : il est ignoré. Un écran qui
/// se recharge à chaque changement s'abonne donc **avant** son chargement
/// initial sans le faire recharger deux fois.
///
/// - une **erreur** d'une source (accès refusé, réseau) est transmise telle
///   quelle ; les autres sources continuent (aucune ne casse les autres) ;
/// - le flux se termine quand **toutes** les sources sont terminées ;
/// - annuler l'abonnement annule **toutes** les sources (aucune écoute ne
///   reste ouverte).
Stream<void> changesOf(List<Stream<Object?>> sources) =>
    _Changes(sources).stream;

class _Changes {
  _Changes(this._sources) {
    _controller = StreamController<void>(
      onListen: _listen,
      onPause: () {
        for (final subscription in _subscriptions) {
          subscription.pause();
        }
      },
      onResume: () {
        for (final subscription in _subscriptions) {
          subscription.resume();
        }
      },
      onCancel: _cancelAll,
    );
  }

  final List<Stream<Object?>> _sources;
  late final StreamController<void> _controller;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  var _open = 0;

  Stream<void> get stream => _controller.stream;

  void _listen() {
    _open = _sources.length;
    if (_open == 0) {
      unawaited(_controller.close());
      return;
    }
    for (final source in _sources) {
      var baseline = true;
      _subscriptions.add(
        source.listen(
          (_) {
            if (baseline) {
              baseline = false;
            } else if (!_controller.isClosed) {
              _controller.add(null);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!_controller.isClosed) _controller.addError(error, stack);
          },
          onDone: () {
            _open--;
            if (_open == 0 && !_controller.isClosed) {
              unawaited(_controller.close());
            }
          },
        ),
      );
    }
  }

  Future<void> _cancelAll() async {
    final subscriptions = _subscriptions.toList();
    _subscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }
}
