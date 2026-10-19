import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_state.freezed.dart';

/// Où en est la synchronisation (pastille discrète, ADR 0024, C4) :
/// `failed` (un envoi refusé par le serveur, à signaler) l'emporte sur
/// `pending` (des écritures validées localement attendent le serveur), qui
/// l'emporte sur `offline` (rien à envoyer, pas de réseau), puis `upToDate`.
enum SyncPhase { upToDate, offline, pending, failed }

/// L'état affiché : jamais de donnée de personne, seulement un nombre de lots.
@freezed
abstract class SyncState with _$SyncState {
  const factory SyncState({
    required SyncPhase phase,

    /// Lots validés localement et pas encore acquittés par le serveur.
    @Default(0) int pending,

    /// Le réseau est coupé (indice : voir `ConnectivityStatus`) ; précise
    /// `pending` (« Hors ligne, envoi en attente »).
    @Default(false) bool offline,
  }) = _SyncState;

  /// Tout est parti et le réseau est là.
  static const upToDate = SyncState(phase: SyncPhase.upToDate);
}

/// Déduit l'état affiché de ce que le suivi des envois et le réseau disent.
SyncState deriveSyncState({
  required int pending,
  required bool online,
  required bool failed,
}) {
  if (failed) {
    return SyncState(
      phase: SyncPhase.failed,
      pending: pending,
      offline: !online,
    );
  }
  if (pending > 0) {
    return SyncState(
      phase: SyncPhase.pending,
      pending: pending,
      offline: !online,
    );
  }
  if (!online) return const SyncState(phase: SyncPhase.offline, offline: true);
  return SyncState.upToDate;
}
