import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

/// Élèves persistés dans SQLite (drift) ; mêmes règles que la version en
/// mémoire, vérifiées par la suite de contrat.
@LazySingleton(env: [Environment.prod])
class DriftStudentRepository implements StudentRepository {
  DriftStudentRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Future<void> save(Student student) => _db.transaction(() async {
    final now = _clock.now();
    await _db
        .into(_db.students)
        .insert(
          StudentsCompanion.insert(
            id: student.id.value,
            firstName: student.firstName,
            createdAt: now,
            updatedAt: now,
          ),
          onConflict: DoUpdate(
            (_) => StudentsCompanion(
              firstName: Value(student.firstName),
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
            target: [_db.students.id],
          ),
        );
    await (_db.delete(
      _db.studentAudienceChanges,
    )..where((c) => c.studentId.equals(student.id.value))).go();
    await _db.batch(
      (batch) => batch.insertAll(_db.studentAudienceChanges, [
        for (final (index, change) in student.audienceHistory.indexed)
          StudentAudienceChangesCompanion.insert(
            studentId: student.id.value,
            position: index,
            audience: change.audience.name,
            effectiveFrom: change.effectiveFrom,
          ),
      ]),
    );
  });

  @override
  Future<Student?> byId(StudentId id) async {
    final row =
        await (_db.select(_db.students)
              ..where((s) => s.id.equals(id.value) & s.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) return null;
    return (await _hydrate([row])).single;
  }

  @override
  Future<List<Student>> all() async {
    final rows =
        await (_db.select(_db.students)
              ..where((s) => s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
            .get();
    return await _hydrate(rows);
  }

  @override
  Future<void> delete(StudentId id) =>
      (_db.update(_db.students)..where((s) => s.id.equals(id.value))).write(
        StudentsCompanion(deletedAt: Value(_clock.now())),
      );

  @override
  Future<void> erase(StudentId id) => _db.transaction(() async {
    await (_db.delete(
      _db.studentAudienceChanges,
    )..where((c) => c.studentId.equals(id.value))).go();
    await (_db.delete(_db.students)..where((s) => s.id.equals(id.value))).go();
  });

  Future<List<Student>> _hydrate(List<StudentRow> rows) async {
    final changes =
        await (_db.select(_db.studentAudienceChanges)
              ..where((c) => c.studentId.isIn([for (final r in rows) r.id]))
              ..orderBy([(c) => OrderingTerm.asc(c.position)]))
            .get();
    return [
      for (final row in rows)
        Student(
          id: StudentId(row.id),
          firstName: row.firstName,
          audienceHistory: [
            for (final change in changes.where((c) => c.studentId == row.id))
              AudienceChange(
                audience: Audience.values.byName(change.audience),
                effectiveFrom: change.effectiveFrom,
              ),
          ],
        ),
    ];
  }
}
