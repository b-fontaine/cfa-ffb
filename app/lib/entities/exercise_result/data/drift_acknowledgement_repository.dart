import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/alert_acknowledgement.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Acquittements d'alertes persistés dans SQLite (drift, ADR 0013).
@LazySingleton(as: AcknowledgementRepository, env: [Environment.prod])
class DriftAcknowledgementRepository implements AcknowledgementRepository {
  DriftAcknowledgementRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Future<void> add(AlertAcknowledgement acknowledgement) async {
    final now = _clock.now();
    await _db
        .into(_db.alertAcknowledgements)
        .insert(
          AlertAcknowledgementsCompanion.insert(
            id: acknowledgement.id.value,
            studentId: acknowledgement.studentId.value,
            blockId: acknowledgement.exercise.blockId,
            exerciseNumber: acknowledgement.exercise.number,
            lastAttemptId: acknowledgement.lastAttemptId.value,
            date: acknowledgement.date,
            createdAt: now,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => AlertAcknowledgementsCompanion(
              studentId: Value(acknowledgement.studentId.value),
              blockId: Value(acknowledgement.exercise.blockId),
              exerciseNumber: Value(acknowledgement.exercise.number),
              lastAttemptId: Value(acknowledgement.lastAttemptId.value),
              date: Value(acknowledgement.date),
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
            target: [_db.alertAcknowledgements.id],
          ),
        );
  }

  @override
  Future<List<AlertAcknowledgement>> forStudent(StudentId studentId) async {
    final found = await _where((a) => a.studentId.equals(studentId.value));
    // Du plus ancien au plus récent (tri stable : ordre d'insertion à égalité).
    return [...found]..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<AlertAcknowledgement>> all() =>
      _where((_) => const Constant(true));

  @override
  Future<void> delete(AcknowledgementId id) =>
      (_db.update(
        _db.alertAcknowledgements,
      )..where((a) => a.id.equals(id.value))).write(
        AlertAcknowledgementsCompanion(deletedAt: Value(_clock.now())),
      );

  @override
  Future<void> eraseStudent(StudentId studentId) => (_db.delete(
    _db.alertAcknowledgements,
  )..where((a) => a.studentId.equals(studentId.value))).go();

  @override
  Future<void> eraseAll() => _db.delete(_db.alertAcknowledgements).go();

  Future<List<AlertAcknowledgement>> _where(
    Expression<bool> Function($AlertAcknowledgementsTable table) filter,
  ) async {
    final rows =
        await (_db.select(_db.alertAcknowledgements)
              ..where((a) => a.deletedAt.isNull() & filter(a))
              ..orderBy([(a) => OrderingTerm.asc(a.seq)]))
            .get();
    return [
      for (final row in rows)
        AlertAcknowledgement(
          id: AcknowledgementId(row.id),
          studentId: StudentId(row.studentId),
          exercise: ExerciseRef(
            blockId: row.blockId,
            number: row.exerciseNumber,
          ),
          lastAttemptId: AttemptId(row.lastAttemptId),
          date: row.date,
        ),
    ];
  }
}
