import 'dart:async';

import 'package:billard_cfa/shared/persistence/document_store.dart';

import 'ui_world.dart';

/// Les envois vers le serveur d'un scénario : des écritures validées
/// localement, que le serveur acquitte ou refuse à la demande. Les complétions
/// d'un scénario sont rattachées à son suivi des envois (un neuf par scénario).
class SyncWorld {
  SyncWorld._();

  static final Expando<List<Completer<void>>> _waiting = Expando();

  static List<Completer<void>> get _mine =>
      _waiting[UiWorld.sends] ??= <Completer<void>>[];

  /// Une écriture attend l'acquittement du serveur.
  static void queueChange() {
    final completer = Completer<void>();
    _mine.add(completer);
    UiWorld.sends.track(completer.future);
  }

  /// Le serveur acquitte tout ce qui attendait.
  static void acknowledgeAll() {
    for (final completer in _mine) {
      if (!completer.isCompleted) completer.complete();
    }
    _mine.clear();
  }

  /// Le serveur refuse une écriture (règle) : le SDK l'annule.
  static void refuseChange() {
    UiWorld.sends.track(
      Future<void>.error(const StoreFailure(StoreFailureCode.permissionDenied)),
    );
  }
}
