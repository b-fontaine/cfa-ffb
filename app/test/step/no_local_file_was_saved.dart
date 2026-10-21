import 'package:flutter_test/flutter_test.dart';

import '../support/local_data_world.dart';

/// Usage: no local file was saved
Future<void> noLocalFileWasSaved(WidgetTester tester) async {
  expect(LocalDataWorld.files.lastSaved, isNull);
}
