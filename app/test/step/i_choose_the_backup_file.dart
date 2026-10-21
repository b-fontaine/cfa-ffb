import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';

/// Usage: I choose the backup file
Future<void> iChooseTheBackupFile(WidgetTester tester) async {
  await ImportScreenWorld.pick(tester);
}
