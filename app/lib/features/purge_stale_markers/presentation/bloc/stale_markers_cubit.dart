import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/bloc/stale_markers_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// La purge des marqueurs abandonnés du club actif, telle que la carte la
/// lance ([PurgeStaleMarkers.call]).
typedef StaleMarkersPurger = Future<StaleMarkerPurgeResult> Function();

/// La carte « Marqueurs abandonnés » (FB8 partie B, B5) : lance la purge,
/// puis montre son issue. Une purge en cours n'est jamais doublée ; après un
/// arrêt, le même bouton relance.
class StaleMarkersCubit extends Cubit<StaleMarkersState> {
  StaleMarkersCubit(this._purge) : super(const StaleMarkersState.idle());

  final StaleMarkersPurger _purge;

  Future<void> purge() async {
    if (state is StaleMarkersRunning) return;
    emit(const StaleMarkersState.running());
    final result = await _purge();
    if (isClosed) return;
    emit(StaleMarkersState.finished(result));
  }
}
