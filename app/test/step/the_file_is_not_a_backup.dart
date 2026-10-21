import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

/// Usage: the file is not a backup
Future<void> theFileIsNotABackup(WidgetTester tester) async {
  ImportWorld.current.content = 'this is not a backup';
}
