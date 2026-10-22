import 'dart:async';

import 'package:billard_cfa/features/close_season/domain/season_closing.dart';
import 'package:billard_cfa/features/manage_students/domain/student_erasure.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';

/// Un effacement **scénarisé** pour les maquettes d'un club synchronisé : il
/// ne touche aucune donnée, il rend l'état que l'écran doit montrer (aperçu,
/// effacement à reprendre, en cours, interrompu).
class ScriptedStudentErasure implements StudentErasure {
  ScriptedStudentErasure({
    required this.status,
    this.outcome,
    this.hang = false,
  });

  final ErasureStatus status;

  /// Le résultat d'une exécution ; sans lui et avec [hang], l'effacement reste
  /// « en cours » (avancement 2 sur 5).
  final ErasureOutcome? outcome;
  final bool hang;

  @override
  Future<Result<ErasureStatus>> inspect(StudentId id) async => Ok(status);

  @override
  Future<Result<ErasureOutcome>> erase(
    StudentId id, {
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) async {
    if (hang) {
      onProgress?.call(2, 5);
      return await Completer<Result<ErasureOutcome>>().future;
    }
    return Ok(
      outcome ??
          const ErasureOutcome(
            status: OperationRunStatus.completed,
            doneLots: 1,
            totalLots: 1,
          ),
    );
  }
}

/// Une clôture **scénarisée** pour les maquettes d'un club synchronisé :
/// reprise d'une clôture commencée, ou clôture en cours.
class ScriptedSeasonClosing implements SeasonClosing {
  ScriptedSeasonClosing({this.pendingTerms, this.hang = false});

  final ClosureTerms? pendingTerms;
  final bool hang;

  @override
  bool get synchronized => true;

  @override
  Future<Result<ClosureTerms?>> pending() async => Ok(pendingTerms);

  @override
  Future<Result<ClosureOutcome>> close({
    required SeasonId seasonId,
    required DateTime closedOn,
    required Set<StudentId> erase,
    bool prepareNext = true,
    bool dropPlanned = true,
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) => _run(onProgress);

  @override
  Future<Result<ClosureOutcome>> resume(
    ClosureTerms terms, {
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) => _run(onProgress);

  Future<Result<ClosureOutcome>> _run(void Function(int, int)? onProgress) {
    if (hang) {
      onProgress?.call(3, 9);
      return Completer<Result<ClosureOutcome>>().future;
    }
    return Future.value(
      const Ok(
        ClosureOutcome(
          status: OperationRunStatus.interrupted,
          doneLots: 3,
          totalLots: 9,
          failure: ServiceFailure(ServiceFailureCode.unavailable),
        ),
      ),
    );
  }
}
