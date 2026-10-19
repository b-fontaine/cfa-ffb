import 'dart:async';

import 'package:billard_cfa/shared/lib/connectivity_status.dart';

/// Ce que la plate-forme sait du réseau : l'état courant et ses changements.
/// Seul le web en a un (`navigator.onLine`, événements `online` et
/// `offline`) ; la liaison est dans `connectivity_web.dart`.
abstract interface class NetworkSignals {
  bool get online;

  /// Appelle [listener] à chaque changement.
  void listen(void Function({required bool online}) listener);
}

/// [ConnectivityStatus] fondé sur des [NetworkSignals] : testable sans
/// navigateur.
class SignalConnectivityStatus implements ConnectivityStatus {
  SignalConnectivityStatus(this._signals) {
    _signals.listen(({required online}) => _changes.add(online));
  }

  final NetworkSignals _signals;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  @override
  bool get online => _signals.online;

  @override
  Stream<bool> get changes => _changes.stream;
}
