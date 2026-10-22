import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';

/// Le résultat d'une exécution de clôture, pour l'écran.
final class ClosureOutcome {
  const ClosureOutcome({
    required this.status,
    this.doneLots = 0,
    this.totalLots = 0,
    this.failure,
    this.result,
  });

  final OperationRunStatus status;
  final int doneLots;
  final int totalLots;
  final ServiceFailure? failure;

  /// Le compte rendu (nombres seulement) d'une clôture menée **sans
  /// interruption** ; une clôture reprise n'en donne pas.
  final ClosureResult? result;

  bool get completed => status == OperationRunStatus.completed;
}

/// Port de l'assistant de clôture : **clore, ou reprendre** une clôture
/// interrompue. Deux réalisations : `LocalSeasonClosing` (drift, une unité de
/// travail : `CloseSeason`) et `ClubSeasonClosing` (club synchronisé, lots
/// reprenables).
abstract interface class SeasonClosing {
  /// Les données sont dans le club : clôture par lots reprenables (avec
  /// avancement, arrêt et reprise) ; sinon sur l'appareil, en une fois.
  bool get synchronized;

  Future<Result<ClosureOutcome>> close({
    required SeasonId seasonId,
    required DateTime closedOn,
    required Set<StudentId> erase,
    bool prepareNext = true,
    bool dropPlanned = true,
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  });

  /// La clôture commencée par ce compte et non terminée, si elle existe.
  Future<Result<ClosureTerms?>> pending();

  /// Reprend la clôture [terms] là où elle s'est arrêtée.
  Future<Result<ClosureOutcome>> resume(
    ClosureTerms terms, {
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  });
}
