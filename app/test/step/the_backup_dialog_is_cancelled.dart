import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the backup dialog is cancelled
Future<void> theBackupDialogIsCancelled(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  (getIt<BackupFiles>() as InMemoryBackupFiles).cancelSave = true;
}
