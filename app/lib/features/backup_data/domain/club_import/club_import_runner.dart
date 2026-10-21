import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:injectable/injectable.dart';

/// Un lot à écrire avec l'avancement du marqueur qui l'accompagne.
final class ImportLotCommit {
  const ImportLotCommit({
    required this.lot,
    required this.marker,
    required this.createsMarker,
    required this.inventory,
  });

  final ImportLot lot;

  /// Le marqueur **après** ce lot (`done` = index du lot + 1).
  final ImportMarker marker;

  /// Premier lot de l'import : le marqueur est créé (sinon, avancé d'un lot).
  final bool createsMarker;

  /// Ce que le club contenait au début de l'exécution : les documents qui
  /// existent déjà ne sont jamais réécrits (ni modifiés).
  final ClubInventory inventory;
}

/// Le club, vu par l'import : son contenu, le marqueur, l'écriture d'un lot.
/// Implémenté par `FirestoreClubImportStore` ; un double en mémoire sert les
/// tests.
abstract interface class ClubImportStore {
  /// L'état du club dans le périmètre du rôle courant, et le marqueur du
  /// fichier [fileId] s'il existe. Aucune donnée personnelle n'en sort.
  Future<ClubInventory> inventory(String fileId);

  /// Le marqueur du fichier [fileId], relu **au serveur** (jamais un cache) ;
  /// `null` s'il n'existe pas.
  Future<ImportMarker?> readMarker(String fileId);

  /// Écrit **en un seul lot atomique** les écritures de [commit] (celles dont
  /// le document n'existe pas déjà) et le marqueur. Lève `ServiceFailure` :
  /// `unavailable` (réseau), `denied` (règles : le marqueur n'était plus celui
  /// attendu, ou un droit manque), `other`.
  Future<void> commit(ImportLotCommit commit);
}

/// Les écritures d'import déjà faites **aujourd'hui** sur cet appareil, par ce
/// compte : l'état qui fait tenir le plafond quotidien entre deux exécutions
/// (sans lui, « Reprendre » juste après une pause écrirait un nouveau budget
/// complet le même jour). Le jour est celui de l'horloge locale ; le quota
/// Spark, lui, est celui du projet : ce plafond borne **cet** appareil, avec la
/// marge de [ImportLimits.dailyWrites] sous le quota.
abstract interface class ImportDailyLedger {
  /// Écritures comptées aujourd'hui (zéro un autre jour).
  Future<int> spentToday();

  /// Ajoute [writes] au compte d'aujourd'hui.
  Future<void> add(int writes);
}

/// Comment s'est arrêtée une exécution.
enum ImportRunStatus {
  /// Tous les lots sont écrits.
  completed,

  /// Le budget du jour est atteint : reprendre un autre jour.
  paused,

  /// Le réseau a manqué : reprendre plus tard (rien n'est perdu).
  interrupted,

  /// Une écriture est refusée (règles) ou a échoué : le lot en cause n'a rien
  /// écrit.
  failed,

  /// L'animateur a demandé l'arrêt : l'exécution s'est arrêtée **entre deux
  /// lots** (jamais au milieu d'un lot atomique) ; la reprise continue au lot
  /// suivant.
  cancelled,

  /// Un import de ce fichier est commencé avec **d'autres choix** : rien n'a
  /// été écrit, l'animateur doit refaire les mêmes choix.
  planChanged,
}

/// Le résultat d'une exécution.
final class ImportRunResult {
  const ImportRunResult({
    required this.status,
    required this.doneLots,
    required this.totalLots,
    this.writes = 0,
    this.failure,
  });

  final ImportRunStatus status;

  /// Lots terminés au total (marqueur compris, reprises comprises).
  final int doneLots;
  final int totalLots;

  /// Écritures de données faites par **cette** exécution.
  final int writes;
  final ServiceFailure? failure;
}

/// Écrit un plan d'import par **lots idempotents reprenables** (ADR 0024,
/// décision 19, C2).
///
/// **Convergence** : chaque lot est un lot atomique qui contient (a) ses
/// écritures, créées seulement si le document n'existe pas déjà, et (b) le
/// passage du marqueur de `k` à `k + 1`. Les règles n'acceptent ce passage que
/// depuis `k` : un même lot ne peut donc **jamais être appliqué deux fois**,
/// même rejoué après une coupure, par deux appareils ou par la file d'attente
/// du SDK. Un lot rejeté parce que le marqueur a déjà avancé est un succès
/// (relu au serveur) ; toute autre erreur laisse le marqueur où il était. Le
/// fichier est identifié par son empreinte : un même compte n'importe pas deux
/// fois le même fichier (le marqueur est par fichier **et** par compte).
///
/// **Budget** : le plafond est **quotidien**, pas par exécution : le compte du
/// jour ([ImportDailyLedger]) est lu au début et incrémenté après chaque lot.
/// Une exécution s'arrête avant le lot qui dépasserait
/// [ImportLimits.dailyWrites] (le premier lot du jour est toujours écrit, pour
/// progresser), et une autre exécution le même jour s'arrête aussitôt
/// (`paused`) ; la reprise a lieu un autre jour, au lot suivant.
///
/// **Écran** (FB7, partie B) : `shouldStop` est lu **avant chaque lot**
/// (annulation propre : `cancelled`, rien n'est à défaire) et `onProgress`
/// reçoit les lots faits sur les lots prévus (début compris, après chaque lot).
@Environment(Environment.prod)
@injectable
class ClubImportRunner {
  const ClubImportRunner(this._store, this._ledger);

  final ClubImportStore _store;
  final ImportDailyLedger _ledger;

  Future<Result<ImportRunResult>> call(
    ClubImportPlan plan, {
    required Role role,
    int? budget,
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) => runGuarded(() async {
    if (!plan.isRunnable) {
      throw const ServiceFailure(ServiceFailureCode.other, 'plan not runnable');
    }
    final inventory = await _store.inventory(plan.fingerprint);
    final marker = inventory.marker;
    if (marker != null && marker.planId != plan.planId) {
      // Un import de ce fichier est commencé avec d'autres choix : rien n'est
      // écrit, et ce n'est pas une erreur (l'animateur refait les mêmes choix).
      return ImportRunResult(
        status: ImportRunStatus.planChanged,
        doneLots: marker.done,
        totalLots: marker.lots,
      );
    }
    final total = plan.lots.length;
    var done = marker?.done ?? 0;
    if (done >= total) {
      return ImportRunResult(
        status: ImportRunStatus.completed,
        doneLots: total,
        totalLots: total,
      );
    }
    onProgress?.call(done, total);
    final limit = budget ?? plan.limits.dailyWrites;
    var spent = await _ledger.spentToday();
    var written = 0;
    var current =
        marker ??
        ImportMarker(
          fileId: plan.fingerprint,
          planId: plan.planId,
          lots: total,
          done: 0,
          writes: plan.totalWrites,
          restored: plan.report.restoredStudents,
          role: role,
        );
    ImportRunResult stop(ImportRunStatus status, [ServiceFailure? failure]) =>
        ImportRunResult(
          status: status,
          doneLots: done,
          totalLots: total,
          writes: written,
          failure: failure,
        );
    while (done < total) {
      // L'arrêt demandé n'interrompt jamais un lot : il se prend entre deux.
      if (shouldStop?.call() ?? false) return stop(ImportRunStatus.cancelled);
      final lot = plan.lots[done];
      final cost = lot.writes.length + 1;
      if (spent > 0 && spent + cost > limit) {
        return stop(ImportRunStatus.paused);
      }
      try {
        await _store.commit(
          ImportLotCommit(
            lot: lot,
            marker: current.advanced(),
            createsMarker: done == 0,
            inventory: inventory,
          ),
        );
      } on ServiceFailure catch (failure) {
        if (failure.code == ServiceFailureCode.unavailable) {
          // Le lot reste dans la file du SDK et sera envoyé : il compte.
          await _ledger.add(cost);
          return stop(ImportRunStatus.interrupted, failure);
        }
        // Le marqueur a peut-être déjà avancé (file d'attente du SDK, autre
        // appareil) : le lot est alors écrit, et c'est un succès.
        final ImportMarker? seen;
        try {
          seen = await _store.readMarker(plan.fingerprint);
        } on ServiceFailure catch (readFailure) {
          return stop(ImportRunStatus.interrupted, readFailure);
        }
        if (failure.code == ServiceFailureCode.denied &&
            seen != null &&
            seen.planId == plan.planId &&
            seen.done > done) {
          done = seen.done;
          current = seen;
          onProgress?.call(done, total);
          continue;
        }
        return stop(ImportRunStatus.failed, failure);
      }
      current = current.advanced();
      done++;
      spent += cost;
      await _ledger.add(cost);
      written += lot.writes.length;
      onProgress?.call(done, total);
    }
    return stop(ImportRunStatus.completed);
  });
}
