import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';
import '../support/realistic_backup.dart';

/// Usage: a backup of a single group
Future<void> aBackupOfASingleGroup(WidgetTester tester) async {
  final single = RealisticBackup(groups: 1);
  ImportWorld.current
    ..backup = single
    ..content = single.content;
}
