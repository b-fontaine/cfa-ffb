import 'dart:io';

import 'package:billard_cfa/entities/student/data/drift_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/drift_storage_status.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/drift_support.dart';

void main() {
  late Directory directory;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    directory = await Directory.systemTemp.createTemp('billard_cfa_db');
  });
  tearDown(() => directory.delete(recursive: true));

  DatabaseSettings settingsInDirectory() => DatabaseSettings(
    native: DriftNativeOptions(
      databaseDirectory: () async => directory,
      tempDirectoryPath: () async => directory.path,
    ),
  );

  test('stores the data in a SQLite file that survives a reopening', () async {
    final first = openAppDatabase(
      status: DriftStorageStatus(),
      settings: settingsInDirectory(),
    );
    await DriftStudentRepository(first, TickingClock()).save(
      Student.enroll(
        id: const StudentId('s1'),
        firstName: 'Léa',
        audience: Audience.children,
        since: DateTime(2026, 9),
      ),
    );
    await first.close();

    final second = openAppDatabase(
      status: DriftStorageStatus(),
      settings: settingsInDirectory(),
    );
    addTearDown(second.close);
    final student = await DriftStudentRepository(
      second,
      TickingClock(),
    ).byId(const StudentId('s1'));

    expect(
      File('${directory.path}/$appDatabaseName.sqlite').existsSync(),
      isTrue,
    );
    expect(student!.firstName, 'Léa');
  });

  test('uses the database name of the application', () {
    expect(appDatabaseName, 'billard_cfa');
  });
}
