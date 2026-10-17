import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/features/backup_data/data/file_picker_backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/download_only_file_picker.dart';
import '../support/ui_world.dart';

/// Usage: the browser downloads backups without a location
Future<void> theBrowserDownloadsBackupsWithoutALocation(
  WidgetTester tester,
) async {
  await UiWorld.prepare(tester);
  final previous = FilePickerPlatform.instance;
  FilePickerPlatform.instance = DownloadOnlyFilePicker();
  addTearDown(() => FilePickerPlatform.instance = previous);
  await getIt.unregister<BackupFiles>();
  getIt.registerSingleton<BackupFiles>(
    FilePickerBackupFiles(savesByDownload: true),
  );
}
