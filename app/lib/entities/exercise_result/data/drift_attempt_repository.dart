import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:billard_cfa/shared/persistence/drift_watch.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Passages persistés dans SQLite (drift).
@LazySingleton(env: [Environment.prod])
class DriftAttemptRepository implements AttemptRepository {
  DriftAttemptRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Future<void> add(ExerciseAttempt attempt) async {
    final now = _clock.now();
    await _db
        .into(_db.attempts)
        .insert(
          AttemptsCompanion.insert(
            id: attempt.id.value,
            studentId: attempt.studentId.value,
            sessionId: attempt.sessionId.value,
            blockId: attempt.exercise.blockId,
            exerciseNumber: attempt.exercise.number,
            date: attempt.date,
            potted: attempt.potted,
            total: attempt.total,
            createdAt: now,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => AttemptsCompanion(
              studentId: Value(attempt.studentId.value),
              sessionId: Value(attempt.sessionId.value),
              blockId: Value(attempt.exercise.blockId),
              exerciseNumber: Value(attempt.exercise.number),
              date: Value(attempt.date),
              potted: Value(attempt.potted),
              total: Value(attempt.total),
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
            target: [_db.attempts.id],
          ),
        );
  }

  @override
  Future<void> correct(ExerciseAttempt attempt) async {
    final updated =
        await (_db.update(_db.attempts)..where(
              (a) => a.id.equals(attempt.id.value) & a.deletedAt.isNull(),
            ))
            .write(
              AttemptsCompanion(
                potted: Value(attempt.potted),
                total: Value(attempt.total),
                updatedAt: Value(_clock.now()),
              ),
            );
    if (updated == 0) throw NotFound('attempt', attempt.id.value);
  }

  @override
  Future<List<ExerciseAttempt>> forStudent(StudentId studentId) =>
      _where((a) => a.studentId.equals(studentId.value));

  @override
  Future<List<ExerciseAttempt>> forSession(SessionId sessionId) =>
      _where((a) => a.sessionId.equals(sessionId.value));

  @override
  Future<List<ExerciseAttempt>> all() => _where((_) => const Constant(true));

  @override
  Future<void> delete(AttemptId id) =>
      (_db.update(_db.attempts)..where((a) => a.id.equals(id.value))).write(
        AttemptsCompanion(deletedAt: Value(_clock.now())),
      );

  @override
  Future<void> eraseStudent(StudentId studentId) => (_db.delete(
    _db.attempts,
  )..where((a) => a.studentId.equals(studentId.value))).go();

  Future<List<ExerciseAttempt>> _where(
    Expression<bool> Function($AttemptsTable table) filter,
  ) async {
    final rows =
        await (_db.select(_db.attempts)
              ..where((a) => a.deletedAt.isNull() & filter(a))
              ..orderBy([(a) => OrderingTerm.asc(a.seq)]))
            .get();
    return [
      for (final row in rows)
        ExerciseAttempt(
          id: AttemptId(row.id),
          studentId: StudentId(row.studentId),
          sessionId: SessionId(row.sessionId),
          exercise: ExerciseRef(
            blockId: row.blockId,
            number: row.exerciseNumber,
          ),
          date: row.date,
          potted: row.potted,
          total: row.total,
        ),
    ];
  }

  @override
  Stream<List<ExerciseAttempt>> watchForStudent(StudentId studentId) =>
      _db.watchTables([_db.attempts], () => forStudent(studentId));

  @override
  Stream<List<ExerciseAttempt>> watchForSession(SessionId sessionId) =>
      _db.watchTables([_db.attempts], () => forSession(sessionId));

  @override
  Stream<List<ExerciseAttempt>> watchAll() =>
      _db.watchTables([_db.attempts], all);
}
