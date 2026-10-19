import 'dart:async';
import 'dart:collection';

import 'package:billard_cfa/shared/persistence/in_memory_journal.dart';

/// Un flux d'**états** d'une lecture : [read] d'abord, puis de nouveau à
/// chaque événement de [changes] (le même état n'est pas rendu deux fois de
/// suite).
///
/// C'est le `watch…` des dépôts sans écoute native (mémoire, drift) :
/// ils savent qu'une table ou une collection a changé, pas ce qui a changé, et
/// relisent. Les changements qui arrivent pendant une lecture sont **fondus
/// en une relecture** (jamais deux lectures en parallèle, jamais un état
/// ancien livré après un état récent). Une lecture qui échoue arrive en erreur
/// sur le flux, qui continue. Annuler l'abonnement annule l'écoute de
/// [changes].
Stream<T> watchRead<T>(Stream<void> changes, Future<T> Function() read) =>
    _Reading<T>(changes, read).stream.distinct(sameState);

/// Deux états sont identiques : mêmes éléments dans le même ordre pour des
/// listes, égalité sinon (les entités du domaine sont comparables par valeur).
bool sameState(Object? a, Object? b) {
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  return a == b;
}

class _Reading<T> {
  _Reading(this._changes, this._read) {
    _controller = StreamController<T>(
      onListen: _start,
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
      onCancel: _stop,
    );
  }

  final Stream<void> _changes;
  final Future<T> Function() _read;
  late final StreamController<T> _controller;
  StreamSubscription<void>? _subscription;
  var _reading = false;
  var _dirty = false;

  Stream<T> get stream => _controller.stream;

  void _start() {
    _subscription = _changes.listen((_) => unawaited(_pump()));
    unawaited(_pump());
  }

  Future<void> _stop() async {
    final current = _subscription;
    _subscription = null;
    await current?.cancel();
  }

  Future<void> _pump() async {
    if (_reading) {
      _dirty = true;
      return;
    }
    _reading = true;
    try {
      do {
        _dirty = false;
        try {
          final value = await _read();
          if (!_controller.isClosed && _controller.hasListener) {
            _controller.add(value);
          }
        } on Object catch (error, stack) {
          if (!_controller.isClosed && _controller.hasListener) {
            _controller.addError(error, stack);
          }
        }
      } while (_dirty && !_controller.isClosed && _controller.hasListener);
    } finally {
      _reading = false;
    }
  }
}

/// Une table en mémoire qui annonce ses modifications : de quoi offrir les
/// `watch…` des dépôts en mémoire (tests, scénarios BDD) sur le même mécanisme
/// que drift.
///
/// Les annonces d'une unité de travail (`InMemoryJournal`) sont **retenues
/// jusqu'à sa fin**, annulation comprise : un abonné ne voit jamais un état à
/// moitié appliqué, comme avec un lot Firestore ou une transaction drift.
class ObservedMap<K, V> extends MapBase<K, V> {
  final Map<K, V> _inner = {};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  /// Un événement à chaque modification (hors unité de travail : aussitôt).
  Stream<void> get changes => _changes.stream;

  /// Les états de [read] : voir [watchRead].
  Stream<T> watch<T>(Future<T> Function() read) => watchRead(changes, read);

  void _announce() => InMemoryJournal.announce(this, _emit);

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  V? operator [](Object? key) => _inner[key];

  @override
  void operator []=(K key, V value) {
    _inner[key] = value;
    _announce();
  }

  @override
  void clear() {
    _inner.clear();
    _announce();
  }

  @override
  Iterable<K> get keys => _inner.keys;

  @override
  V? remove(Object? key) {
    final removed = _inner.remove(key);
    _announce();
    return removed;
  }
}
