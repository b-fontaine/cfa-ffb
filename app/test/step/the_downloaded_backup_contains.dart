import 'dart:convert';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/download_only_file_picker.dart';

/// Usage: the downloaded backup contains {'Léa'}
Future<void> theDownloadedBackupContains(
  WidgetTester tester,
  String text,
) async {
  final picker = FilePickerPlatform.instance as DownloadOnlyFilePicker;
  expect(picker.downloads, hasLength(1));
  expect(picker.downloads.single.fileName, endsWith('.json'));
  expect(utf8.decode(picker.downloads.single.bytes), contains(text));
}
