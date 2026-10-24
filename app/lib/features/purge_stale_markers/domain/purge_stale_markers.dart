import 'package:billard_cfa/features/purge_stale_markers/domain/stale_markers.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';

/// Comment s'est arrêtée une purge.
enum StaleMarkerPurgeStatus {
  /// Tout ce qui était ancien est supprimé (ou il n'y avait rien).
  completed,

  /// Le plafond d'écritures du jour est atteint : reprendre demain.
  paused,

  /// Le réseau a manqué : relancer plus tard (rien n'est perdu).
  interrupted,

  /// Refusée (rôle, règles) ou en échec : le lot en cause n'a rien supprimé.
  failed,
}

/// L'issue d'une purge : combien de marqueurs sont **réellement** supprimés
/// (lots acquittés par le serveur), et pourquoi elle s'est arrêtée.
final class StaleMarkerPurgeResult {
  const StaleMarkerPurgeResult({
    required this.status,
    required this.removed,
    this.failure,
  });

  final StaleMarkerPurgeStatus status;
  final int removed;
  final ServiceFailure? failure;
}

/// Cas d'usage : **purger les marqueurs abandonnés du club actif** (FB8
/// partie B, B5 ; décision D4 du 2026-10-24 ; ADR 0024 décision 19). C'est le
/// filet de la suppression d'un compte (B1, B2 : l'auteur retire les siens) :
/// un marqueur d'un auteur déjà parti, ou d'une opération jamais reprise, dont
/// le dernier lot a plus de [staleMarkerAge], est supprimé par un gestionnaire
/// du club, quel qu'en soit l'auteur.
///
/// - **Rôle** : le directeur et l'administrateur (`Capability.manageClub`,
///   le `manages` des règles) ; tout autre compte est refusé **avant toute
///   lecture**.
/// - **Lecture bornée** : imports puis opérations, par une requête de plage
///   `updatedAt < maintenant − (90 jours + marge)` ([staleMarkerClockMargin]).
/// - **Lots** de [maxOwnMarkerLot] suppressions au plus, chacun acquitté par
///   le serveur avant le suivant.
/// - **Plafond quotidien** partagé avec l'import et les opérations
///   ([DailyWriteLedger]) : un lot qui le dépasserait n'est pas envoyé
///   (`paused`) ; le premier lot du jour part toujours.
/// - **Reprise** : relancer liste de nouveau ce qui reste ; un lot coupé
///   (`interrupted`) peut encore partir depuis la file du SDK, il est compté.
final class PurgeStaleMarkers {
  const PurgeStaleMarkers(
    this._store,
    this._ledger,
    this._clock,
    this._scope, {
    this.limits = const OperationLimits(),
  });

  final StaleMarkerStore _store;
  final DailyWriteLedger _ledger;
  final Clock _clock;
  final ActiveClubScope _scope;
  final OperationLimits limits;

  Future<StaleMarkerPurgeResult> call() async {
    final club = _scope.clubId;
    final role = _scope.role;
    var removed = 0;
    StaleMarkerPurgeResult stop(
      StaleMarkerPurgeStatus status, [
      ServiceFailure? failure,
    ]) => StaleMarkerPurgeResult(
      status: status,
      removed: removed,
      failure: failure,
    );
    StaleMarkerPurgeResult stopOn(ServiceFailure failure) => stop(
      failure.code == ServiceFailureCode.unavailable
          ? StaleMarkerPurgeStatus.interrupted
          : StaleMarkerPurgeStatus.failed,
      failure,
    );

    if (club == null || role == null || !role.can(Capability.manageClub)) {
      return stop(
        StaleMarkerPurgeStatus.failed,
        const ServiceFailure(ServiceFailureCode.denied, 'rôle'),
      );
    }
    final before = _clock.now().subtract(
      staleMarkerAge + staleMarkerClockMargin,
    );
    var spent = await _ledger.spentToday();
    for (final kind in MarkerKind.values) {
      final List<StaleMarker> markers;
      try {
        markers = await _store.list(club, kind, before);
      } on ServiceFailure catch (failure) {
        return stopOn(failure);
      }
      for (var start = 0; start < markers.length; start += maxOwnMarkerLot) {
        final end = start + maxOwnMarkerLot < markers.length
            ? start + maxOwnMarkerLot
            : markers.length;
        final cost = end - start;
        if (spent > 0 && spent + cost > limits.dailyWrites) {
          return stop(StaleMarkerPurgeStatus.paused);
        }
        try {
          await _store.delete(club, markers.sublist(start, end));
        } on ServiceFailure catch (failure) {
          if (failure.code == ServiceFailureCode.unavailable) {
            // Le lot reste dans la file du SDK et peut encore partir.
            await _ledger.add(cost);
          }
          return stopOn(failure);
        }
        spent += cost;
        await _ledger.add(cost);
        removed += cost;
      }
    }
    return stop(StaleMarkerPurgeStatus.completed);
  }
}
