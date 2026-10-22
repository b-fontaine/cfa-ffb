import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/drift_support.dart';
import '../../../support/fixtures.dart';

Student _student(String name) => Student.enroll(
  id: const StudentId('s1'),
  firstName: name,
  audience: Audience.children,
  since: DateTime(2026, 9),
);

void main() {
  late AppDatabase db;
  late DriftStudentRepository students;

  setUp(() {
    db = openMemoryDatabase();
    students = DriftStudentRepository(db, TickingClock());
  });
  tearDown(() => db.close());

  Future<StudentRow> row() => db.select(db.students).getSingle();

  test('stamps createdAt and updatedAt on the first save', () async {
    await students.create(_student('Léa'));

    final saved = await row();
    expect(saved.createdAt, DateTime.utc(2026, 10));
    expect(saved.updatedAt, DateTime.utc(2026, 10));
    expect(saved.deletedAt, isNull);
  });

  test('keeps createdAt and refreshes updatedAt when saved again', () async {
    await students.create(_student('Léa'));
    await students.create(_student('Léa-Rose'));

    final saved = await row();
    expect(saved.firstName, 'Léa-Rose');
    expect(saved.createdAt, DateTime.utc(2026, 10));
    expect(saved.updatedAt, DateTime.utc(2026, 10, 1, 0, 1));
  });

  test('keeps a deleted student in the table with its deletion date', () async {
    await students.create(_student('Léa'));
    await students.delete(const StudentId('s1'));

    final saved = await row();
    expect(saved.deletedAt, DateTime.utc(2026, 10, 1, 0, 1));
    expect(await students.all(), isEmpty);
  });

  test('clears the deletion date when the student is saved again', () async {
    await students.create(_student('Léa'));
    await students.delete(const StudentId('s1'));
    await students.create(_student('Léa'));

    expect((await row()).deletedAt, isNull);
  });

  test('keeps the insertion order of the first save', () async {
    await students.create(_student('Léa'));
    final first = (await row()).seq;
    await students.create(_student('Léa-Rose'));

    expect((await row()).seq, first);
  });

  test(
    'stores dates as ISO 8601 text and keeps soft-deleted attempts',
    () async {
      final attempts = DriftAttemptRepository(db, TickingClock());
      await attempts.add(attempt(ref('a', 1), potted: 3));
      await attempts.delete(const AttemptId('a1'));

      final raw = await db
          .customSelect('SELECT date, deleted_at FROM attempts')
          .get();

      expect(raw.single.read<String>('date'), '2026-10-01T00:00:00.000');
      expect(raw.single.read<String?>('deleted_at'), isNotNull);
      expect(await attempts.all(), isEmpty);
    },
  );
}
