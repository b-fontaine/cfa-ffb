import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'stale_markers_state.freezed.dart';

/// La carte « Marqueurs abandonnés » de « Mon club ».
@freezed
sealed class StaleMarkersState with _$StaleMarkersState {
  /// Rien n'est demandé.
  const factory StaleMarkersState.idle() = StaleMarkersIdle;

  /// La purge est en cours.
  const factory StaleMarkersState.running() = StaleMarkersRunning;

  /// La purge s'est arrêtée : [result] dit combien sont supprimés et
  /// pourquoi. Le même bouton relance (ce qui reste se relit au serveur).
  const factory StaleMarkersState.finished(StaleMarkerPurgeResult result) =
      StaleMarkersFinished;
}
