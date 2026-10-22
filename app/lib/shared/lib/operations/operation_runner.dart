import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';

/// Comment s'est arrêtée une exécution.
enum OperationRunStatus {
  /// Tout est fait (ou c'était déjà fait).
  completed,

  /// Le budget du jour est atteint : reprendre un autre jour.
  paused,

  /// Le réseau a manqué : reprendre plus tard (rien n'est perdu).
  interrupted,

  /// Une écriture est refusée (règles) ou a échoué : le lot en cause n'a rien
  /// écrit.
  failed,

  /// L'arrêt a été demandé : l'exécution s'est arrêtée **entre deux lots**
  /// (jamais au milieu d'un lot atomique) ; la reprise continue au lot suivant.
  cancelled,
}

/// Le résultat d'une exécution.
final class OperationRunResult {
  const OperationRunResult({
    required this.status,
    required this.doneLots,
    required this.totalLots,
    this.writes = 0,
    this.failure,
    this.alreadyDone = false,
  });

  final OperationRunStatus status;

  /// Lots terminés au total (reprises comprises) et lots prévus (estimation :
  /// ce qui reste se recalcule à chaque étape).
  final int doneLots;
  final int totalLots;

  /// Écritures de données faites par **cette** exécution.
  final int writes;
  final ServiceFailure? failure;

  /// L'opération était déjà achevée avant cette exécution : rien n'a été écrit.
  final bool alreadyDone;
}

/// Exécute une [ResumableOperation] par **lots idempotents reprenables** (ADR
/// 0024, décision 19 ; FB8 partie A). C'est le moteur qu'avait prouvé l'import
/// d'une sauvegarde (FB7), généralisé : l'effacement d'un élève et la clôture
/// d'une saison l'utilisent.
///
/// **Convergence** : chaque lot est un lot atomique qui contient (a) ses
/// écritures et (b) le passage du marqueur de `k` à `k + 1`. Les règles
/// n'acceptent ce passage que depuis `k` : un même lot ne peut donc **jamais
/// être appliqué deux fois**, même rejoué après une coupure, par un second
/// appareil du même compte ou par la file d'attente du SDK. Un lot rejeté parce
/// que le marqueur a déjà avancé est un succès relu au serveur : l'exécution
/// repart de l'avancement vu, en **recalculant** le travail qui reste. Chaque
/// écriture étant idempotente (suppression, retrait d'un élément de liste,
/// écriture d'un contenu déterminé), le même état final est atteint quel que
/// soit l'endroit où l'exécution s'arrête.
///
/// **Plan** : chaque étape calcule son travail d'après l'état courant **avant**
/// d'écrire son premier lot ; une étape sans travail avance le marqueur d'un
/// lot vide. Le **premier** lot crée le marqueur, le **dernier** le supprime :
/// le marqueur n'existe que pendant l'opération.
///
/// **Budget** : le plafond est **quotidien** (le compte du jour est lu au début
/// et incrémenté après chaque lot) ; une exécution s'arrête avant le lot qui le
/// dépasserait (le premier lot du jour est toujours écrit, pour progresser).
class OperationRunner {
  const OperationRunner(
    this._store,
    this._ledger, {
    this.limits = const OperationLimits(),
  });

  final OperationStore _store;
  final DailyWriteLedger _ledger;
  final OperationLimits limits;

  Future<Result<OperationRunResult>> call(
    ResumableOperation operation, {
    required Role role,
    int? budget,
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) => runGuarded(() async {
    final stages = operation.stages;
    var marker = await _store.readMarker(operation.key);
    if (marker == null && await operation.isAlreadyDone()) {
      return const OperationRunResult(
        status: OperationRunStatus.completed,
        doneLots: 0,
        totalLots: 0,
        alreadyDone: true,
      );
    }
    final limit = budget ?? limits.dailyWrites;
    var spent = await _ledger.spentToday();
    var written = 0;
    var done = marker?.done ?? 0;
    var total = done;
    OperationRunResult stop(OperationRunStatus status, [ServiceFailure? f]) =>
        OperationRunResult(
          status: status,
          doneLots: done,
          totalLots: total < done ? done : total,
          writes: written,
          failure: f,
        );

    var stage = marker?.stage ?? 0;
    while (stage < stages.length) {
      final planned = await stages[stage].remaining(limits.dataWrites);
      // Une étape sans travail avance quand même le marqueur.
      final lots = planned.isEmpty ? [OperationLot.empty] : planned;
      final isLast = stage == stages.length - 1;
      total = done + lots.length + (stages.length - 1 - stage);
      onProgress?.call(done, total);
      var resync = false;
      for (var i = 0; i < lots.length && !resync; i++) {
        if (shouldStop?.call() ?? false) {
          return stop(OperationRunStatus.cancelled);
        }
        final lot = lots[i];
        final cost = lot.writes + 1;
        if (spent > 0 && spent + cost > limit) {
          return stop(OperationRunStatus.paused);
        }
        final lastOfStage = i == lots.length - 1;
        final finishes = isLast && lastOfStage;
        final before =
            marker ??
            OperationMarker(
              key: operation.key,
              kind: operation.kind,
              done: 0,
              stage: 0,
              role: role,
              terms: operation.terms,
            );
        final after = before.advanced(
          nextStage: lastOfStage ? stage + 1 : stage,
        );
        try {
          await _store.commit(
            OperationLotCommit(
              lot: lot,
              marker: after,
              createsMarker: marker == null,
              finishes: finishes,
            ),
          );
        } on ServiceFailure catch (failure) {
          if (failure.code == ServiceFailureCode.unavailable) {
            // Le lot reste dans la file du SDK et sera envoyé : il compte.
            await _ledger.add(cost);
            return stop(OperationRunStatus.interrupted, failure);
          }
          // Le marqueur a peut-être déjà avancé (file d'attente du SDK, autre
          // appareil) : relu au serveur.
          final OperationMarker? seen;
          try {
            seen = await _store.readMarker(operation.key);
          } on ServiceFailure catch (readFailure) {
            return stop(OperationRunStatus.interrupted, readFailure);
          }
          if (seen != null && seen.done > (marker?.done ?? 0)) {
            marker = seen;
            done = seen.done;
            stage = seen.stage;
            resync = true;
            continue;
          }
          if (seen == null &&
              marker != null &&
              await operation.isAlreadyDone()) {
            // Un autre appareil a terminé : le marqueur a disparu avec ce
            // qu'il achevait.
            done = total;
            return stop(OperationRunStatus.completed);
          }
          return stop(OperationRunStatus.failed, failure);
        }
        marker = finishes ? null : after;
        done++;
        spent += cost;
        await _ledger.add(cost);
        written += lot.writes;
        onProgress?.call(done, total);
      }
      if (!resync) stage++;
    }
    return stop(OperationRunStatus.completed);
  });
}
