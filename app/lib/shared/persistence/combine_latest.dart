import 'dart:async';

/// L'état le plus récent de **toutes** les [sources], à chaque changement de
/// l'une d'elles (rien tant que chacune n'a pas donné un premier état ; un état
/// vide, puis la fin, sans source).
///
/// C'est la brique des `watch…` qui lisent plusieurs écoutes à la fois (un
/// groupe et ses appartenances, une requête par groupe d'un enseignant) :
/// - une **erreur** de l'une termine l'ensemble (livrée une fois) et libère
///   **toutes** les autres écoutes ; c'est la règle des écoutes Firestore, et
///   un état incomplet ne serait jamais exact ;
/// - annuler l'abonnement annule toutes les sources ;
/// - la fin n'arrive que quand toutes les sources sont finies.
Stream<List<T>> combineLatest<T>(List<Stream<T>> sources) =>
    _Combination<T>(sources).stream;

class _Combination<T> {
  _Combination(this._sources) {
    _controller = StreamController<List<T>>(
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
      onCancel: _release,
    );
  }

  final List<Stream<T>> _sources;
  late final StreamController<List<T>> _controller;
  final List<StreamSubscription<T>> _subscriptions = [];
  late final List<T?> _latest = List<T?>.filled(_sources.length, null);
  late final List<bool> _ready = List<bool>.filled(_sources.length, false);
  var _open = 0;

  Stream<List<T>> get stream => _controller.stream;

  void _listen() {
    _open = _sources.length;
    if (_open == 0) {
      _controller.add(<T>[]);
      unawaited(_controller.close());
      return;
    }
    for (var i = 0; i < _sources.length; i++) {
      _subscriptions.add(
        _sources[i].listen(
          (event) => _onEvent(i, event),
          onError: _fail,
          onDone: _onDone,
        ),
      );
    }
  }

  void _onEvent(int index, T event) {
    _latest[index] = event;
    _ready[index] = true;
    if (_controller.isClosed || _ready.contains(false)) return;
    _controller.add([for (final value in _latest) value as T]);
  }

  void _fail(Object error, StackTrace stack) {
    if (_controller.isClosed) return;
    _controller.addError(error, stack);
    unawaited(_finish());
  }

  void _onDone() {
    _open--;
    if (_open == 0) unawaited(_finish());
  }

  Future<void> _release() async {
    final subscriptions = _subscriptions.toList();
    _subscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }

  Future<void> _finish() async {
    await _release();
    if (!_controller.isClosed) await _controller.close();
  }
}
