import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/closure_checks.dart';
import 'package:billard_cfa/features/close_season/domain/season_closing.dart';
import 'package:billard_cfa/features/close_season/domain/season_closure_operation.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/closure_limits.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';

/// La clôture d'une saison dans un **club synchronisé** : l'opération
/// reprenable de FB8 (`SeasonClosureOperation`) menée par `OperationRunner`,
/// avec les vérifications de `CloseSeason` avant toute écriture. Réservée aux
/// rôles de la capacité `closeSeason` (`RolePolicy`, source unique de la
/// matrice).
///
/// **Limite** : au plus [maxErasedPerClosure] élèves effacés par clôture (le
/// premier lot les déclare tous avec le marqueur) ; au-delà, refus
/// (`InvariantCode.tooManyToErase`) avant toute écriture. **Fenêtre de
/// migration** : aucune clôture pendant l'import d'une sauvegarde (règle de
/// l'ADR 0024, inchangée : l'écran de clôture n'est pas proposé tant qu'un
/// import est en cours).
class ClubSeasonClosing implements SeasonClosing {
  ClubSeasonClosing(
    this._runner,
    this._store,
    this._purge,
    this._repositories,
    this._scope,
  );

  final OperationRunner _runner;
  final OperationStore _store;
  final StudentPurge _purge;
  final ClosureRepositories _repositories;
  final ActiveClubScope _scope;

  @override
  bool get synchronized => true;

  Role get _manager {
    final role = _scope.role;
    if (role != null && role.can(Capability.closeSeason)) return role;
    throw const ServiceFailure(ServiceFailureCode.denied, 'role');
  }

  @override
  Future<Result<ClosureOutcome>> close({
    required SeasonId seasonId,
    required DateTime closedOn,
    required Set<StudentId> erase,
    bool prepareNext = true,
    bool dropPlanned = true,
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) => runGuarded(() async {
    final role = _manager;
    // Une clôture de cette saison déjà commencée par ce compte se **reprend**
    // avec les termes de son marqueur : jamais avec de nouveaux choix, que
    // l'étape passée ignorerait en silence.
    if (await _store.readMarker(
          operationKey(OperationKind.closure, seasonId.value),
        ) !=
        null) {
      throw const InvariantViolation(InvariantCode.closurePending);
    }
    if (erase.length > maxErasedPerClosure) {
      throw const InvariantViolation(InvariantCode.tooManyToErase);
    }
    final checked = await checkClosure(
      seasons: _repositories.seasons,
      groups: _repositories.groups,
      students: _repositories.students,
      seasonId: seasonId,
      closedOn: closedOn,
      erase: erase,
    );
    final operation = SeasonClosureOperation(
      repositories: _repositories,
      purge: _purge,
      closureTerms: ClosureTerms(
        seasonId: seasonId,
        closedOn: checked.day,
        prepareNext: prepareNext,
        dropPlanned: dropPlanned,
      ),
      erase: erase,
    );
    final outcome = await _run(
      operation,
      role,
      shouldStop: shouldStop,
      onProgress: onProgress,
    );
    if (!outcome.completed) return outcome;
    return ClosureOutcome(
      status: outcome.status,
      doneLots: outcome.doneLots,
      totalLots: outcome.totalLots,
      result: ClosureResult(
        erased: erase.length,
        kept: checked.kept.length,
        groupsPrepared: operation.groupsPrepared,
        plannedDropped: operation.plannedDropped,
      ),
    );
  });

  @override
  Future<Result<ClosureTerms?>> pending() => runGuarded(() async {
    _manager;
    for (final marker in await _store.ownMarkers()) {
      if (marker.kind == OperationKind.closure && marker.terms != null) {
        return marker.terms;
      }
    }
    return null;
  });

  @override
  Future<Result<ClosureOutcome>> resume(
    ClosureTerms terms, {
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) => runGuarded(() async {
    final role = _manager;
    return await _run(
      SeasonClosureOperation(
        repositories: _repositories,
        purge: _purge,
        closureTerms: terms,
      ),
      role,
      shouldStop: shouldStop,
      onProgress: onProgress,
    );
  });

  Future<ClosureOutcome> _run(
    SeasonClosureOperation operation,
    Role role, {
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) async {
    switch (await _runner(
      operation,
      role: role,
      shouldStop: shouldStop,
      onProgress: onProgress,
    )) {
      case Ok(:final value):
        return ClosureOutcome(
          status: value.status,
          doneLots: value.doneLots,
          totalLots: value.totalLots,
          failure: value.failure,
        );
      case Err(:final failure):
        throw failure;
    }
  }
}
