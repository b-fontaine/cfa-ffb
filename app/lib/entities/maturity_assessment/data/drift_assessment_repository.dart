import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Bilans de maturité persistés dans SQLite (drift).
@LazySingleton(env: [Environment.prod])
class DriftAssessmentRepository implements AssessmentRepository {
  DriftAssessmentRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Future<void> add(MaturityAssessment assessment) async {
    final now = _clock.now();
    await _db
        .into(_db.assessments)
        .insert(
          AssessmentsCompanion.insert(
            id: assessment.id.value,
            studentId: assessment.studentId.value,
            date: assessment.date,
            concentration: assessment.concentration,
            endurance: assessment.endurance,
            frustration: assessment.frustration,
            comment: Value(assessment.comment),
            createdAt: now,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => AssessmentsCompanion(
              studentId: Value(assessment.studentId.value),
              date: Value(assessment.date),
              concentration: Value(assessment.concentration),
              endurance: Value(assessment.endurance),
              frustration: Value(assessment.frustration),
              comment: Value(assessment.comment),
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
            target: [_db.assessments.id],
          ),
        );
  }

  @override
  Future<List<MaturityAssessment>> forStudent(StudentId studentId) async =>
      (await _where((a) => a.studentId.equals(studentId.value)))
        ..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<List<MaturityAssessment>> all() => _where((_) => const Constant(true));

  @override
  Future<void> delete(AssessmentId id) =>
      (_db.update(_db.assessments)..where((a) => a.id.equals(id.value))).write(
        AssessmentsCompanion(deletedAt: Value(_clock.now())),
      );

  @override
  Future<void> eraseStudent(StudentId studentId) => (_db.delete(
    _db.assessments,
  )..where((a) => a.studentId.equals(studentId.value))).go();

  Future<List<MaturityAssessment>> _where(
    Expression<bool> Function($AssessmentsTable table) filter,
  ) async {
    final rows =
        await (_db.select(_db.assessments)
              ..where((a) => a.deletedAt.isNull() & filter(a))
              ..orderBy([(a) => OrderingTerm.asc(a.seq)]))
            .get();
    return [
      for (final row in rows)
        MaturityAssessment(
          id: AssessmentId(row.id),
          studentId: StudentId(row.studentId),
          date: row.date,
          concentration: row.concentration,
          endurance: row.endurance,
          frustration: row.frustration,
          comment: row.comment,
        ),
    ];
  }
}
