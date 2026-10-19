import 'dart:async';

import 'package:billard_cfa/features/sync_status/domain/sync_state.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';
import 'package:billard_cfa/shared/lib/send_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// État de la pastille de synchronisation : le suivi des envois
/// (`SendStatus`, alimenté par l'unité de travail Firestore) et l'indice de
/// réseau (`ConnectivityStatus`) donnent un [SyncState].
///
/// Un refus tardif du serveur (règle, quota) reste affiché jusqu'à ce que
/// l'animateur en prenne acte ([acknowledgeFailure]) : le SDK a annulé la
/// modification de son cache, il faut le lui dire.
@injectable
class SyncStatusCubit extends Cubit<SyncState> {
  SyncStatusCubit(this._sends, this._network) : super(SyncState.upToDate) {
    emit(_derive());
    _subscriptions = [
      _sends.pendingChanges.listen((_) => _refresh()),
      _network.changes.listen((_) {
        _refresh();
        unawaited(_sends.refresh());
      }),
    ];
    // Les écritures qui attendaient déjà dans le SDK au lancement.
    unawaited(_sends.refresh());
  }

  final SendStatus _sends;
  final ConnectivityStatus _network;
  late final List<StreamSubscription<Object?>> _subscriptions;

  /// L'animateur a lu le message d'échec : on l'oublie.
  void acknowledgeFailure() {
    _sends.clearFailure();
    _refresh();
  }

  void _refresh() {
    if (!isClosed) emit(_derive());
  }

  SyncState _derive() => deriveSyncState(
    pending: _sends.pending,
    online: _network.online,
    failed: _sends.hasFailure,
  );

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
  }
}
