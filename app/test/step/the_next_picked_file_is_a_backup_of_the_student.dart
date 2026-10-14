import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_snapshot.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the next picked file is a backup of the student {'Zoé'}
Future<void> theNextPickedFileIsABackupOfTheStudent(
  WidgetTester tester,
  String name,
) async {
  await UiWorld.prepare(tester);
  final content = getIt<BackupCodec>().encode(
    BackupSnapshot(
      seasons: [
        Season(
          id: const SeasonId('backup-season'),
          label: '2026-2027',
          startDate: DateTime(2026, 9),
          endDate: DateTime(2027, 8, 31),
        ),
      ],
      students: [
        Student.enroll(
          id: const StudentId('backup-student'),
          firstName: name,
          audience: Audience.children,
          since: DateTime(2026, 9),
        ),
      ],
      blockAcquisitions: const [],
    ),
    exportedAt: DateTime.utc(2026, 10),
  );
  (getIt<BackupFiles>() as InMemoryBackupFiles).nextPick = content;
}
