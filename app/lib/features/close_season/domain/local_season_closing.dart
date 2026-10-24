import 'package:billard_cfa/features/close_season/domain/close_season.dart';
import 'package:billard_cfa/features/close_season/domain/season_closing.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';

/// La clôture **sur l'appareil** (drift) : `CloseSeason` en une unité de
/// travail, inchangée par FB8. Ni reprise ni avancement : tout ou rien,
/// instantané.
class LocalSeasonClosing implements SeasonClosing {
  LocalSeasonClosing(this._close);

  final CloseSeason _close;

  @override
  bool get synchronized => false;

  @override
  Future<Result<ClosureOutcome>> close({
    required SeasonId seasonId,
    required DateTime closedOn,
    required Set<StudentId> erase,
    bool prepareNext = true,
    bool dropPlanned = true,
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) async {
    switch (await _close(
      seasonId: seasonId,
      closedOn: closedOn,
      erase: erase,
      prepareNext: prepareNext,
      dropPlanned: dropPlanned,
    )) {
      case Ok(:final value):
        return Ok(
          ClosureOutcome(
            status: OperationRunStatus.completed,
            doneLots: 1,
            totalLots: 1,
            result: value,
          ),
        );
      case Err(:final failure):
        return Err(failure);
    }
  }

  @override
  Future<Result<ClosureTerms?>> pending() async => const Ok(null);

  @override
  Future<Result<int>> invitationsToPurge() async => const Ok(0);

  @override
  Future<Result<ClosureOutcome>> resume(
    ClosureTerms terms, {
    bool Function()? shouldStop,
    void Function(int done, int total)? onProgress,
  }) async => const Err(
    ServiceFailure(ServiceFailureCode.unsupported, 'no resumable closure'),
  );
}
