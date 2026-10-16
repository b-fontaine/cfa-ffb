import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/close_season/domain/build_archive.dart';
import 'package:billard_cfa/features/close_season/domain/closure_plan.dart';
import 'package:billard_cfa/features/close_season/domain/planned_after_closure.dart';
import 'package:billard_cfa/features/close_season/domain/propose_closure.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : préparer l'assistant de clôture (lecture seule). Rien n'est
/// écrit ; les propositions viennent de la règle pure `proposeClosure`.
@injectable
class PrepareSeasonClosure {
  PrepareSeasonClosure(
    this._seasons,
    this._groups,
    this._students,
    this._sessionRecords,
    this._attempts,
    this._plannedSessions,
  );

  final SeasonRepository _seasons;
  final GroupRepository _groups;
  final StudentRepository _students;
  final SessionRecordRepository _sessionRecords;
  final AttemptRepository _attempts;
  final SessionRepository _plannedSessions;

  Future<Result<ClosurePlan>> call({
    required SeasonId seasonId,
    required DateTime today,
  }) => runGuarded(() async {
    final season = await _seasons.byId(seasonId);
    if (season == null) throw NotFound('season', seasonId.value);
    if (season.isClosed) {
      throw const InvariantViolation(InvariantCode.seasonAlreadyClosed);
    }
    final groups = await _groups.all();
    final sessions = await _sessionRecords.all();
    final archive = buildArchive(
      season: season,
      groups: groups,
      sessions: sessions,
      attempts: await _attempts.all(),
    );
    final day = today.dateOnly;
    // Jamais avant le début : la clôture exige un jour postérieur au début.
    final closedOn = day.isAfter(season.startDate)
        ? day
        : season.startDate.add(const Duration(days: 1)).dateOnly;
    final groupIds = {
      for (final group in groups)
        if (group.seasonId == seasonId) group.id,
    };
    final dropped = plannedAfterClosure(
      season: season,
      groupIds: groupIds,
      planned: await _plannedSessions.getAll(),
      day: closedOn,
    );
    return ClosurePlan(
      season: season,
      closedOn: closedOn,
      early: closedOn.isBefore(season.endDate),
      audiences: archive.audiences,
      proposals: proposeClosure(
        season: season,
        seasons: await _seasons.all(),
        students: await _students.all(),
        groups: groups,
        sessions: sessions,
      ),
      plannedToDrop: dropped.length,
    );
  });
}
