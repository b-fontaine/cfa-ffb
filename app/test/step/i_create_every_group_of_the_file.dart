import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';
import '../support/import_world.dart';

/// Usage: I create every group of the file
Future<void> iCreateEveryGroupOfTheFile(WidgetTester tester) async {
  for (final group in ImportWorld.current.backup!.snapshot.groups) {
    final menu = ImportScreenWorld.groupMenu(group.name);
    if (menu.evaluate().isEmpty) continue;
    await ImportScreenWorld.choose(tester, menu, 'Create in the club');
  }
}
