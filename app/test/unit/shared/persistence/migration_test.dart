import 'package:billard_cfa/entities/exercise_result/data/drift_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/drift_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_source.dart';
import 'package:billard_cfa/entities/exercise_result/domain/block_acquisition.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/drift_assessment_repository.dart';
import 'package:billard_cfa/entities/session/data/drift_session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/drift_session_record_repository.dart';
import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/features/backup_data/data/drift_backup_marker_repository.dart';
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

  test('a fresh database matches the committed v3 snapshot', () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 3);
  });

  test('a fresh database matches the committed v4 snapshot', () async {
    final connection = await verifier.startAt(4);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 4);
  });

  test('a fresh database matches the committed v5 snapshot', () async {
    final connection = await verifier.startAt(5);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 5);
  });

  test('a fresh database matches the committed v6 snapshot', () async {
    final connection = await verifier.startAt(6);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 6);
  });

  test('upgrading v5 to v6 creates an empty backup history and keeps '
      'attempts', () async {
    final schema = await verifier.schemaAt(5);
    schema.rawDatabase
      ..execute(
        'INSERT INTO students (id, created_at, updated_at, first_name) '
        "VALUES ('s1', '2026-10-01T00:00:00.000Z', "
        "'2026-10-01T00:00:00.000Z', 'Léa')",
      )
      ..execute(
        'INSERT INTO attempts (id, created_at, updated_at, student_id, '
        'session_id, block_id, exercise_number, date, pass_index, potted, '
        'total) '
        "VALUES ('a1', '2026-10-01T00:00:00.000Z', "
        "'2026-10-01T00:00:00.000Z', 's1', 'x1', 'posture', 1, "
        "'2026-10-01T00:00:00.000', 1, 3, 5)",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 6);

    expect(await DriftBackupMarkerRepository(db).last(), isNull);
    final attempt = (await DriftAttemptRepository(
      db,
      TickingClock(),
    ).all()).single;
    expect(attempt.id.value, 'a1');
    expect(attempt.potted, 3);
  });

  test('upgrading v4 to v5 creates an empty acquisitions table and keeps '
      'attempts', () async {
    final schema = await verifier.schemaAt(4);
    schema.rawDatabase
      ..execute(
        'INSERT INTO students (id, created_at, updated_at, first_name) '
        "VALUES ('s1', '2026-10-01T00:00:00.000Z', "
        "'2026-10-01T00:00:00.000Z', 'Léa')",
      )
      ..execute(
        'INSERT INTO attempts (id, created_at, updated_at, student_id, '
        'session_id, block_id, exercise_number, date, pass_index, potted, '
        'total) '
        "VALUES ('a1', '2026-10-01T00:00:00.000Z', "
        "'2026-10-01T00:00:00.000Z', 's1', 'x1', 'posture', 1, "
        "'2026-10-01T00:00:00.000', 1, 3, 5)",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 5);

    final clock = TickingClock();
    expect(await DriftAcquisitionRepository(db, clock).all(), isEmpty);
    final attempt = (await DriftAttemptRepository(db, clock).all()).single;
    expect(attempt.id.value, 'a1');
    expect(attempt.potted, 3);
    final acquisitions = DriftAcquisitionRepository(db, clock);
    await acquisitions.add(
      BlockAcquisition(
        id: const AcquisitionId('q1'),
        studentId: const StudentId('s1'),
        blockId: 'posture',
        date: DateTime(2026, 10, 5),
        source: AcquisitionSource.placement,
      ),
    );
    final read = (await acquisitions.forStudent(const StudentId('s1'))).single;
    expect(read.blockId, 'posture');
    expect(read.date, DateTime(2026, 10, 5));
    expect(read.source, AcquisitionSource.placement);
  });

  test('upgrading v3 to v4 dates planned sessions from their creation and '
      'keeps records without catalogue session', () async {
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase
      ..execute(
        'INSERT INTO planned_sessions (id, created_at, updated_at, title, '
        'audience, sheet_id) '
        "VALUES ('p1', '2026-10-01T00:00:00.000Z', "
        "'2026-10-02T00:00:00.000Z', 'Rebond', 'adults', 'rebond-bande-1')",
      )
      ..execute(
        'INSERT INTO session_records (id, created_at, updated_at, group_id, '
        'season_id, date, audience, main_block_id) '
        "VALUES ('x1', '2026-10-01T00:00:00.000Z', "
        "'2026-10-01T00:00:00.000Z', 'g1', 's1', '2026-10-03T00:00:00.000', "
        "'children', 'posture')",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 4);

    final clock = TickingClock();
    final planned = (await DriftSessionRepository(db, clock).getAll()).single;
    expect(planned.id, 'p1');
    expect(planned.title, 'Rebond');
    expect(planned.date, DateTime.utc(2026, 10));
    expect(planned.audience.name, 'adults');
    expect(planned.groupId, isNull);
    expect(planned.sheetId?.value, 'rebond-bande-1');
    final record = (await DriftSessionRecordRepository(db, clock).all()).single;
    expect(record.id.value, 'x1');
    expect(record.date, DateTime(2026, 10, 3));
    expect(record.mainBlockId, 'posture');
    expect(record.sheetId, isNull);
  });

  test(
    'upgrading v2 to v3 adds the sheet and keeps planned sessions',
    () async {
      final schema = await verifier.schemaAt(2);
      schema.rawDatabase.execute(
        'INSERT INTO planned_sessions (id, created_at, updated_at, title, '
        'audience) '
        "VALUES ('p1', '2026-10-01T00:00:00.000Z', "
        "'2026-10-01T00:00:00.000Z', 'Rebond', 'children')",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, 3);

      // Le dépôt lit le schéma courant (v5) : la ligne v3 se vérifie en SQL.
      final row =
          (await db
                  .customSelect(
                    'SELECT id, title, sheet_id FROM planned_sessions',
                  )
                  .get())
              .single
              .data;
      expect(row['id'], 'p1');
      expect(row['title'], 'Rebond');
      expect(row['sheet_id'], isNull);
    },
  );

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
        setup: (raw) => raw.execute('PRAGMA user_version = 7'),
      ),
    );
    addTearDown(db.close);

    await expectLater(
      db.customSelect('SELECT 1').get(),
      throwsA(
        isA<DowngradeNotSupported>()
            .having((e) => e.from, 'from', 7)
            .having((e) => e.to, 'to', 6)
            .having((e) => e.toString(), 'message', contains('version 7')),
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
