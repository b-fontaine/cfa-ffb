import 'dart:async';

import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:injectable/injectable.dart';

/// État de l'**envoi** des écritures vers le serveur (ADR 0024, décisions 1 et
/// 19 ; hors ligne, C4) : un lot est d'abord **validé localement** (le SDK
/// Firestore l'applique à son cache dès l'appel), puis envoyé ; le serveur ne
/// l'acquitte que lorsqu'il répond, parfois bien plus tard (hors ligne). Le
/// lot validé n'attend donc pas ce port : l'interface (FB5, pastille « Envoi
/// en attente ») le lit.
abstract interface class SendStatus {
  /// Lots validés localement et pas encore acquittés par le serveur.
  int get pending;

  /// Émet le nombre de lots en attente à chaque changement.
  Stream<int> get pendingChanges;

  /// Le dernier envoi refusé par le serveur (règles, quota), `null` sinon. Le
  /// SDK annule alors la modification de son cache : l'interface doit le dire.
  StoreFailure? get lastFailure;

  /// Oublie [lastFailure] (l'animateur en a pris connaissance).
  void clearFailure();
}

/// Suivi des envois : `FirestoreUnitOfWork` lui confie le `Future` du lot
/// envoyé au lieu de l'attendre.
@LazySingleton()
class SendTracker implements SendStatus {
  final StreamController<int> _changes = StreamController<int>.broadcast();
  int _pending = 0;
  StoreFailure? _lastFailure;

  @override
  int get pending => _pending;

  @override
  Stream<int> get pendingChanges => _changes.stream;

  @override
  StoreFailure? get lastFailure => _lastFailure;

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
