import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the saved backup file contains {'Léa'}
Future<void> theSavedBackupFileContains(
  WidgetTester tester,
  String text,
) async {
  final saved = (getIt<BackupFiles>() as InMemoryBackupFiles).lastSaved;
  expect(saved, isNotNull);
  expect(saved!.fileName, endsWith('.json'));
  expect(saved.content, contains(text));
}
