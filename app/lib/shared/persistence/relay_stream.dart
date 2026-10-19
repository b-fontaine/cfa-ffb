import 'dart:async';

/// Relaie [source] en convertissant chaque événement, et **termine** le flux
/// (en annulant [source]) à la première erreur, à la première conversion qui
/// échoue ou dès que [valid] devient faux.
///
/// C'est la règle des écoutes Firestore, tenue partout où un flux en traverse
/// un autre : une erreur (règle qui refuse, accès perdu) est livrée **une
/// fois** puis le flux se ferme, et fermer ne laisse aucune écoute derrière
/// soi (l'annulation de l'abonné annule [source]). Le relais respecte la pause
/// de l'abonné.
///
/// - [data] convertit un événement ; ce qu'il lève est livré (traduit par
///   [error]) et ferme le flux ;
/// - [error] traduit une erreur de [source] ou de [data] ;
/// - [valid] est testée avant chaque événement : faux, [invalid] fournit
///   l'erreur livrée avant la fermeture ;
/// - [recheck] (flux de diffusion) : à chaque signal, [valid] est aussi
///   testée, **sans attendre un événement** de [source] : un flux devenu
///   invalide se ferme (et relâche sa source) dès le signal. Le relais cesse
///   d'écouter [recheck] en se fermant.
Stream<R> relayStream<E, R>(
  Stream<E> source, {
  required R Function(E event) data,
  Object Function(Object error)? error,
  bool Function()? valid,
  Object Function()? invalid,
  Stream<void>? recheck,
}) => _Relay<E, R>(source, data, error, valid, invalid, recheck).stream;

class _Relay<E, R> {
  _Relay(
    this._source,
    this._data,
    this._error,
    this._valid,
    this._invalid,
    this._recheck,
  ) {
    _controller = StreamController<R>(
      onListen: _listen,
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
      onCancel: _release,
    );
  }

  final Stream<E> _source;
  final R Function(E) _data;
  final Object Function(Object)? _error;
  final bool Function()? _valid;
  final Object Function()? _invalid;
  final Stream<void>? _recheck;

  late final StreamController<R> _controller;
  StreamSubscription<E>? _subscription;
  StreamSubscription<void>? _rechecking;

  Stream<R> get stream => _controller.stream;

  void _listen() {
    _subscription = _source.listen(
      _onEvent,
      onError: _fail,
      onDone: () => unawaited(_finish()),
    );
    _rechecking = _recheck?.listen((_) => _check());
  }

  bool _check() {
    final valid = _valid;
    if (valid == null || valid()) return true;
    _fail(_invalid?.call() ?? StateError('flux invalidé'), StackTrace.current);
    return false;
  }

  void _onEvent(E event) {
    if (!_check()) return;
    final R converted;
    try {
      converted = _data(event);
    } on Object catch (failure, stack) {
      _fail(failure, stack);
      return;
    }
    if (!_controller.isClosed) _controller.add(converted);
  }

  void _fail(Object failure, StackTrace stack) {
    if (_controller.isClosed) return;
    final translate = _error;
    _controller.addError(
      translate == null ? failure : translate(failure),
      stack,
    );
    unawaited(_finish());
  }

  Future<void> _release() async {
    final current = _subscription;
    _subscription = null;
    unawaited(_rechecking?.cancel());
    _rechecking = null;
    await current?.cancel();
  }

  Future<void> _finish() async {
    await _release();
    if (!_controller.isClosed) await _controller.close();
  }
}
