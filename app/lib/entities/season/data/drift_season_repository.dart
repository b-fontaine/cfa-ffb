import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Saisons persistées dans SQLite (drift).
@LazySingleton(as: SeasonRepository, env: [Environment.prod])
class DriftSeasonRepository implements SeasonRepository {
  DriftSeasonRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Future<void> save(Season season) async {
    final now = _clock.now();
    await _db
        .into(_db.seasons)
        .insert(
          SeasonsCompanion.insert(
            id: season.id.value,
            label: season.label,
            startDate: season.startDate,
            endDate: season.endDate,
            closedOn: Value(season.closedOn),
            createdAt: now,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => SeasonsCompanion(
              label: Value(season.label),
              startDate: Value(season.startDate),
              endDate: Value(season.endDate),
              closedOn: Value(season.closedOn),
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
            target: [_db.seasons.id],
          ),
        );
  }

  @override
  Future<Season?> byId(SeasonId id) async {
    final row =
        await (_db.select(_db.seasons)
              ..where((s) => s.id.equals(id.value) & s.deletedAt.isNull()))
            .getSingleOrNull();
    return row == null ? null : _toSeason(row);
  }

  @override
  Future<List<Season>> all() async {
    final rows =
        await (_db.select(_db.seasons)
              ..where((s) => s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
            .get();
    return rows.map(_toSeason).toList();
  }

  @override
  Future<void> delete(SeasonId id) =>
      (_db.update(_db.seasons)..where((s) => s.id.equals(id.value))).write(
        SeasonsCompanion(deletedAt: Value(_clock.now())),
      );

  Season _toSeason(SeasonRow row) => Season(
    id: SeasonId(row.id),
    label: row.label,
    startDate: row.startDate,
    endDate: row.endDate,
    closedOn: row.closedOn,
  );
}
