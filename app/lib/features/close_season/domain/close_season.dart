import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/choose_group.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_calendar.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/close_season/domain/build_archive.dart';
import 'package:billard_cfa/features/close_season/domain/planned_after_closure.dart';
import 'package:billard_cfa/features/close_season/domain/propose_closure.dart';
import 'package:billard_cfa/features/close_season/domain/student_eraser.dart';
import 'package:billard_cfa/shared/lib/date_only.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unique_name.dart';
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
    final season = await _seasons.byId(seasonId);
    if (season == null) throw NotFound('season', seasonId.value);
    if (season.isClosed) {
      throw const InvariantViolation(InvariantCode.seasonAlreadyClosed);
    }
    final day = closedOn.dateOnly;
    if (!day.isAfter(season.startDate)) {
      throw const InvariantViolation(InvariantCode.invalidPeriod);
    }
    final groups = await _groups.all();
    final seasonGroups = [
      for (final group in groups)
        if (group.seasonId == seasonId) group,
    ];
    final candidates = closureCandidates(
      season: season,
      students: await _students.all(),
      groups: groups,
      seasons: await _seasons.all(),
    );
    for (final id in erase) {
      if (!candidates.contains(id)) throw NotFound('student', id.value);
    }
    // Reconduits : ceux qui ont encore une appartenance ouverte dans la
    // saison et ne sont pas effacés (ceux qui l'avaient déjà quittée ne le
    // sont pas).
    final kept = <StudentId>{
      for (final group in seasonGroups)
        for (final membership in group.memberships)
          if (membership.to == null && !erase.contains(membership.studentId))
            membership.studentId,
    };

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
  /// reconduits (créés ou retrouvés).
  Future<int> _prepareNext(
    Season closed,
    DateTime day,
    Set<StudentId> erased,
  ) async {
    final seasons = await _seasons.all();
    final candidate = nextSeasonAfter(
      closed,
      SeasonId(_ids.next()),
      takenLabels: {for (final s in seasons) s.label},
    );
    final existing = seasons
        .where((s) => s.id != closed.id && s.overlaps(candidate))
        .firstOrNull;
    if (existing != null && existing.isClosed) return 0;
    final next = existing ?? candidate;
    if (existing == null) await _seasons.save(next);
    // Les élèves reconduits rejoignent la saison suivante dès son premier
    // jour, même si la clôture a lieu après : ils ne sont pas « sans groupe »
    // entre son début et la clôture. L'ancienne appartenance finit la veille.
    final from = next.startDate.dateOnly;
    final lastDay = DateTime(from.year, from.month, from.day - 1);
    final releaseOn = lastDay.isBefore(day) ? lastDay : day;

    final all = await _groups.all();
    var prepared = 0;
    for (final origin in all.where((g) => g.seasonId == closed.id)) {
      var destination =
          _homonym(all, next.id, origin) ?? _fresh(all, next, origin);
      var released = origin;
      for (final membership in origin.memberships) {
        if (membership.to != null || erased.contains(membership.studentId)) {
          continue;
        }
        released = released.release(
          studentId: membership.studentId,
          to: releaseOn.isBefore(membership.from) ? membership.from : releaseOn,
        );
        destination = destination.admit(
          studentId: membership.studentId,
          studentAudience: destination.audience,
          from: from,
        );
      }
      await _groups.save(released);
      await _groups.save(destination);
      prepared++;
    }
    return prepared;
  }

  Group? _homonym(List<Group> all, SeasonId seasonId, Group origin) {
    final wanted = normalizedGroupName(origin.name);
    for (final group in all) {
      if (group.seasonId == seasonId &&
          normalizedGroupName(group.name) == wanted &&
          group.audience == origin.audience) {
        return group;
      }
    }
    return null;
  }

  /// Un groupe neuf de la saison [next] portant le nom de [origin] ; si ce nom
  /// y est pris par un groupe d'un autre public, il est suffixé (« (2) »,
  /// « (3) »… jusqu'à un nom libre : le nom reste unique dans la saison).
  Group _fresh(List<Group> all, Season next, Group origin) {
    final taken = {
      for (final g in all)
        if (g.seasonId == next.id) normalizedGroupName(g.name),
    };
    return Group(
      id: GroupId(_ids.next()),
      seasonId: next.id,
      name: firstFreeName(
        origin.name,
        (c) => taken.contains(normalizedGroupName(c)),
      ),
      audience: origin.audience,
    );
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
