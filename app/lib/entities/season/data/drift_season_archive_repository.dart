import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Archives de saisons persistées dans SQLite (drift, ADR 0019) : deux tables
/// d'agrégats, remplacées en bloc par saison.
@LazySingleton(as: SeasonArchiveRepository, env: [Environment.prod])
class DriftSeasonArchiveRepository implements SeasonArchiveRepository {
  DriftSeasonArchiveRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> save(SeasonArchive archive) => _db.transaction(() async {
    await _erase(archive.seasonId);
    await _db.batch((batch) {
      batch
        ..insertAll(_db.seasonArchiveAudiences, [
          for (final a in archive.audiences)
            SeasonArchiveAudiencesCompanion.insert(
              seasonId: archive.seasonId.value,
              audience: a.audience.name,
              sessionCount: a.sessionCount,
              presenceCount: a.presenceCount,
              possiblePresenceCount: a.possiblePresenceCount,
              studentCount: a.studentCount,
              attemptCount: a.attemptCount,
            ),
        ])
        ..insertAll(_db.seasonArchiveExercises, [
          for (final e in archive.exercises)
            SeasonArchiveExercisesCompanion.insert(
              seasonId: archive.seasonId.value,
              audience: e.audience.name,
              blockId: e.exercise.blockId,
              exerciseNumber: e.exercise.number,
              studentCount: e.studentCount,
              attemptCount: e.attemptCount,
              potted: e.potted,
              total: e.total,
            ),
        ]);
    });
  });

  @override
  Future<SeasonArchive?> bySeason(SeasonId seasonId) async {
    final all = await _read(seasonId);
    return all.firstOrNull;
  }

  @override
  Future<List<SeasonArchive>> all() => _read(null);

  @override
  Future<void> delete(SeasonId seasonId) => _erase(seasonId);

  Future<void> _erase(SeasonId seasonId) async {
    await (_db.delete(
      _db.seasonArchiveAudiences,
    )..where((a) => a.seasonId.equals(seasonId.value))).go();
    await (_db.delete(
      _db.seasonArchiveExercises,
    )..where((e) => e.seasonId.equals(seasonId.value))).go();
  }

  /// Ordre canonique des publics (celui de l'énumération), pour que la lecture
  /// rende les blocs dans l'ordre où l'agrégat les écrit.
  static List<T> _byAudience<T>(
    Iterable<T> rows,
    String Function(T row) audienceOf,
  ) => [...rows]
    ..sort(
      (a, b) => Audience.values
          .byName(audienceOf(a))
          .index
          .compareTo(Audience.values.byName(audienceOf(b)).index),
    );

  Future<List<SeasonArchive>> _read(SeasonId? seasonId) async {
    final audienceQuery = _db.select(_db.seasonArchiveAudiences)
      ..orderBy([(a) => OrderingTerm.asc(a.seasonId)]);
    final exerciseQuery = _db.select(_db.seasonArchiveExercises)
      ..orderBy([
        (e) => OrderingTerm.asc(e.seasonId),
        (e) => OrderingTerm.asc(e.audience),
        (e) => OrderingTerm.asc(e.blockId),
        (e) => OrderingTerm.asc(e.exerciseNumber),
      ]);
    if (seasonId != null) {
      audienceQuery.where((a) => a.seasonId.equals(seasonId.value));
      exerciseQuery.where((e) => e.seasonId.equals(seasonId.value));
    }
    final audiences = await audienceQuery.get();
    final exercises = await exerciseQuery.get();
    final ids = {
      ...audiences.map((a) => a.seasonId),
      ...exercises.map((e) => e.seasonId),
    }.toList()..sort();
    return [
      for (final id in ids)
        SeasonArchive(
          seasonId: SeasonId(id),
          audiences: [
            for (final a in _byAudience(
              audiences.where((a) => a.seasonId == id),
              (a) => a.audience,
            ))
              AudienceArchive(
                audience: Audience.values.byName(a.audience),
                sessionCount: a.sessionCount,
                presenceCount: a.presenceCount,
                possiblePresenceCount: a.possiblePresenceCount,
                studentCount: a.studentCount,
                attemptCount: a.attemptCount,
              ),
          ],
          exercises: [
            for (final e in _byAudience(
              exercises.where((e) => e.seasonId == id),
              (e) => e.audience,
            ))
              ExerciseArchive(
                audience: Audience.values.byName(e.audience),
                exercise: ExerciseRef(
                  blockId: e.blockId,
                  number: e.exerciseNumber,
                ),
                studentCount: e.studentCount,
                attemptCount: e.attemptCount,
                potted: e.potted,
                total: e.total,
              ),
          ],
        ),
    ];
  }
}
