import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/close_season/domain/build_archive.dart';
import 'package:billard_cfa/features/close_season/domain/closure_checks.dart';
import 'package:billard_cfa/features/close_season/domain/next_season_plan.dart';
import 'package:billard_cfa/features/close_season/domain/planned_after_closure.dart';
import 'package:billard_cfa/features/close_season/domain/student_eraser.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'close_season.freezed.dart';

/// Compte rendu d'une clôture : des nombres seulement. Aucun prénom, aucun
/// identifiant : les élèves effacés n'existent plus et rien ne les nomme
/// (ADR 0019).
@freezed
abstract class ClosureResult with _$ClosureResult {
  const factory ClosureResult({
    required int erased,
    required int kept,
    required int groupsPrepared,
    required int plannedDropped,
  }) = _ClosureResult;
}

/// Cas d'usage : clore une saison (ADR 0019), en **une seule unité de
/// travail** : tout ou rien, archive comprise.
///
/// Dans l'ordre : (1) calculer l'archive agrégée à partir des données
/// complètes ; (2) l'enregistrer ; (3) poser `closedOn` et ramener la fin de
/// saison au jour de clôture si elle est postérieure ; (4) effacer
/// physiquement chaque élève de `erase` (par `StudentEraser`) ; (5) si
/// `prepareNext` : préparer la saison suivante, ses groupes homonymes, et y
/// placer les élèves reconduits ; (6) si `dropPlanned` : supprimer les
/// séances planifiées de la saison postérieures à la clôture.
///
/// L'effacement passe par le port `StudentEraser`, relié par la couche `app` à
/// `EraseStudent` : la liste des dépôts nominatifs n'existe qu'une fois
/// (`erasure_parity_test`).
@injectable
class CloseSeason {
  CloseSeason(
    this._seasons,
    this._groups,
    this._students,
    this._sessionRecords,
    this._attempts,
    this._plannedSessions,
    this._archives,
    this._eraser,
    this._ids,
    this._unitOfWork,
  );

  final SeasonRepository _seasons;
  final GroupRepository _groups;
  final StudentRepository _students;
  final SessionRecordRepository _sessionRecords;
  final AttemptRepository _attempts;
  final SessionRepository _plannedSessions;
  final SeasonArchiveRepository _archives;
  final StudentEraser _eraser;
  final IdGenerator _ids;
  final UnitOfWork _unitOfWork;

  Future<Result<ClosureResult>> call({
    required SeasonId seasonId,
    required DateTime closedOn,
    required Set<StudentId> erase,
    bool prepareNext = true,
    bool dropPlanned = true,
  }) => runGuarded(() async {
    final checked = await checkClosure(
      seasons: _seasons,
      groups: _groups,
      students: _students,
      seasonId: seasonId,
      closedOn: closedOn,
      erase: erase,
    );
    final season = checked.season;
    final day = checked.day;
    final groups = checked.groups;
    final seasonGroups = checked.seasonGroups;
    final kept = checked.kept;

    // (1) L'archive se calcule sur les données complètes, avant l'effacement.
    final archive = buildArchive(
      season: season,
      groups: groups,
      sessions: await _sessionRecords.all(),
      attempts: await _attempts.all(),
    );
    final closed = season.copyWith(
      closedOn: day,
      endDate: day.isBefore(season.endDate) ? day : season.endDate,
    );

    var prepared = 0;
    var dropped = 0;
    await _unitOfWork.run(() async {
      await _archives.save(archive);
      await _seasons.save(closed);
      for (final id in erase) {
        await _eraser.erase(id);
      }
      if (prepareNext) {
        prepared = await _prepareNext(closed, day, erase);
      }
      if (dropPlanned) {
        dropped = await _dropPlanned(season, seasonGroups, day);
      }
    });
    return ClosureResult(
      erased: erase.length,
      kept: kept.length,
      groupsPrepared: prepared,
      plannedDropped: dropped,
    );
  });

  /// Prépare la saison qui suit [closed] ; rend le nombre de groupes
  /// reconduits (créés ou retrouvés). La règle est `planNextSeason`, partagée
  /// avec la clôture reprenable.
  Future<int> _prepareNext(
    Season closed,
    DateTime day,
    Set<StudentId> erased,
  ) async {
    final groups = await _groups.all();
    final plan = planNextSeason(
      closed: closed,
      day: day,
      seasons: await _seasons.all(),
      groups: groups,
      erased: erased,
      newSeasonId: SeasonId(_ids.next()),
      newGroupId: (_) => GroupId(_ids.next()),
    );
    if (plan == null) return 0;
    if (plan.seasonToSave case final next?) await _seasons.save(next);
    for (final step in plan.steps) {
      await _groups.save(step.released);
      await _groups.save(step.destination);
    }
    return groups.where((g) => g.seasonId == closed.id).length;
  }

  Future<int> _dropPlanned(
    Season season,
    List<Group> seasonGroups,
    DateTime day,
  ) async {
    final dropped = plannedAfterClosure(
      season: season,
      groupIds: {for (final group in seasonGroups) group.id},
      planned: await _plannedSessions.getAll(),
      day: day,
    );
    for (final planned in dropped) {
      await _plannedSessions.delete(planned.id);
    }
    return dropped.length;
  }
}
