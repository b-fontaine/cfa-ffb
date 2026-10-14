import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Blocs acquis au positionnement persistés dans SQLite (drift).
@LazySingleton(as: AcquisitionRepository, env: [Environment.prod])
class DriftAcquisitionRepository implements AcquisitionRepository {
  DriftAcquisitionRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Future<void> add(BlockAcquisition acquisition) async {
    final now = _clock.now();
    await _db
        .into(_db.blockAcquisitions)
        .insert(
          BlockAcquisitionsCompanion.insert(
            id: acquisition.id.value,
            studentId: acquisition.studentId.value,
            blockId: acquisition.blockId,
            date: acquisition.date,
            source: acquisition.source.name,
            createdAt: now,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => BlockAcquisitionsCompanion(
              studentId: Value(acquisition.studentId.value),
              blockId: Value(acquisition.blockId),
              date: Value(acquisition.date),
              source: Value(acquisition.source.name),
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
            target: [_db.blockAcquisitions.id],
          ),
        );
  }

  @override
  Future<List<BlockAcquisition>> forStudent(StudentId studentId) async {
    final found = await _where((a) => a.studentId.equals(studentId.value));
    // Du plus ancien au plus récent (tri stable : ordre d'insertion à égalité).
    return [...found]..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<BlockAcquisition>> all() => _where((_) => const Constant(true));

  @override
  Future<void> delete(AcquisitionId id) =>
      (_db.update(_db.blockAcquisitions)..where((a) => a.id.equals(id.value)))
          .write(BlockAcquisitionsCompanion(deletedAt: Value(_clock.now())));

  @override
  Future<void> eraseStudent(StudentId studentId) => (_db.delete(
    _db.blockAcquisitions,
  )..where((a) => a.studentId.equals(studentId.value))).go();

  Future<List<BlockAcquisition>> _where(
    Expression<bool> Function($BlockAcquisitionsTable table) filter,
  ) async {
    final rows =
        await (_db.select(_db.blockAcquisitions)
              ..where((a) => a.deletedAt.isNull() & filter(a))
              ..orderBy([(a) => OrderingTerm.asc(a.seq)]))
            .get();
    return [
      for (final row in rows)
        BlockAcquisition(
          id: AcquisitionId(row.id),
          studentId: StudentId(row.studentId),
          blockId: row.blockId,
          date: row.date,
          source: AcquisitionSource.values.byName(row.source),
        ),
    ];
  }
}
