import 'dart:async';

import 'package:billard_cfa/shared/lib/send_status.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:injectable/injectable.dart';

/// Suivi des envois (implémente [SendStatus]) : `FirestoreUnitOfWork` lui
/// confie le `Future` du lot envoyé au lieu de l'attendre.
@LazySingleton()
class SendTracker implements SendStatus {
  SendTracker(this._probe);

  final PendingWritesProbe _probe;
  bool _restored = false;
  final StreamController<int> _changes = StreamController<int>.broadcast();
  int _pending = 0;
  StoreFailure? _lastFailure;

  @override
  int get pending => _pending;

  @override
  Stream<int> get pendingChanges => _changes.stream;

  /// Le dernier envoi refusé par le serveur (règles, quota), `null` sinon : le
  /// SDK annule alors la modification de son cache.
  StoreFailure? get lastFailure => _lastFailure;

  @override
  Future<bool> hasUnsentWrites() async =>
      _pending > 0 || await _probe.hasPending();

  /// Les écritures **déjà en file dans le SDK** (écrites avant un
  /// rechargement ou un redémarrage) comptent comme un lot en attente jusqu'à
  /// ce que le SDK ait vidé sa file : le compteur en mémoire les ignore sinon.
  @override
  Future<void> refresh() async {
    if (_restored || _pending > 0) return;
    if (!await _probe.hasPending() || _restored) return;
    _restored = true;
    track(_probe.untilSent().whenComplete(() => _restored = false));
  }

  @override
  bool get hasFailure => _lastFailure != null;

  @override
  void clearFailure() => _lastFailure = null;

  /// Suit [send] sans jamais lever : un refus du serveur devient
  /// [lastFailure], pas une exception sans appelant.
  void track(Future<void> send) {
    _set(_pending + 1);
    unawaited(
      send.then<void>(
        (_) => _set(_pending - 1),
        onError: (Object error) {
          _lastFailure = error is StoreFailure
              ? error
              : StoreFailure(StoreFailureCode.other, '$error');
          _set(_pending - 1);
        },
      ),
    );
  }

  void _set(int value) {
    _pending = value;
    _changes.add(value);
  }
}
