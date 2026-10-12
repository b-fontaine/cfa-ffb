import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/app_database.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../drift/app_database/generated/schema.dart';
import '../../../support/drift_support.dart';

void main() {
  late SchemaVerifier verifier;

  setUp(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the schema version matches the latest snapshot', () {
    expect(AppDatabase.currentSchemaVersion, GeneratedHelper.versions.last);

    final db = openMemoryDatabase();
    addTearDown(db.close);
    expect(db.schemaVersion, GeneratedHelper.versions.last);
  });

  test('a fresh database matches the committed v1 snapshot', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 1);
  });

  test('a fresh database matches the committed v2 snapshot', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 2);
  });

  test('upgrading v1 to v2 adds the comment and keeps assessments', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      'INSERT INTO assessments (id, created_at, updated_at, student_id, '
      'date, concentration, endurance, frustration) '
      "VALUES ('b1', '2026-10-01T00:00:00.000Z', "
      "'2026-10-01T00:00:00.000Z', 's1', '2026-10-01T00:00:00.000', 3, 2, 4)",
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 2);

    final assessment = (await DriftAssessmentRepository(
      db,
      TickingClock(),
    ).all()).single;
    expect(assessment.id.value, 'b1');
    expect(assessment.concentration, 3);
    expect(assessment.comment, isNull);
  });

  test('a database created by the snapshot is readable as is', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase
      ..execute(
        'INSERT INTO students (id, created_at, updated_at, first_name) '
        "VALUES ('s1', '2026-10-01T00:00:00.000Z', "
        "'2026-10-01T00:00:00.000Z', 'Léa')",
      )
      ..execute(
        'INSERT INTO student_audience_changes '
        '(student_id, position, audience, effective_from) '
        "VALUES ('s1', 0, 'children', '2026-09-01T00:00:00.000')",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    final student = await DriftStudentRepository(
      db,
      TickingClock(),
    ).byId(const StudentId('s1'));

    expect(student!.firstName, 'Léa');
    expect(student.audienceHistory.single.effectiveFrom, DateTime(2026, 9));
  });

  test('refuses to open a database written by a newer version', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 3'),
      ),
    );
    addTearDown(db.close);

    await expectLater(
      db.customSelect('SELECT 1').get(),
      throwsA(
        isA<DowngradeNotSupported>()
            .having((e) => e.from, 'from', 3)
            .having((e) => e.to, 'to', 2)
            .having((e) => e.toString(), 'message', contains('version 3')),
      ),
    );
  });

  test('enforces foreign keys', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);

    final rows = await db.customSelect('PRAGMA foreign_keys').get();

    expect(rows.single.data.values.single, 1);
  });
}
