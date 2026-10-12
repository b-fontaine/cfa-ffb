import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:billard_cfa/shared/persistence/drift_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/drift_support.dart';
import '../../../support/fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openMemoryDatabase());
  tearDown(() => db.close());

  test('rolls back every write of the unit when the body fails', () async {
    final clock = TickingClock();
    final students = DriftStudentRepository(db, clock);
    final attempts = DriftAttemptRepository(db, clock);

    await expectLater(
      DriftUnitOfWork(db).run<void>(() async {
        await students.save(
          Student.enroll(
            id: const StudentId('s1'),
            firstName: 'Léa',
            audience: Audience.children,
            since: DateTime(2026, 9),
          ),
        );
        await attempts.add(attempt(ref('a', 1), potted: 3));
        throw StateError('write failed');
      }),
      throwsStateError,
    );

    expect(await students.all(), isEmpty);
    expect(await attempts.all(), isEmpty);
  });

  test('commits every write of the unit when the body succeeds', () async {
    final attempts = DriftAttemptRepository(db, TickingClock());

    final count = await DriftUnitOfWork(db).run(() async {
      await attempts.add(attempt(ref('a', 1), potted: 3));
      await attempts.add(attempt(ref('a', 2), potted: 3, id: 'a2'));
      return (await attempts.all()).length;
    });

    expect(count, 2);
    expect(await attempts.all(), hasLength(2));
  });
}
