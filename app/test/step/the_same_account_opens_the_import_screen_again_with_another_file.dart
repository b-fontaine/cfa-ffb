import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';
import '../support/import_world.dart';
import '../support/realistic_backup.dart';

/// Usage: the same account opens the import screen again with another file
Future<void> theSameAccountOpensTheImportScreenAgainWithAnotherFile(
  WidgetTester tester,
) async {
  final other = RealisticBackup(groups: 1);
  ImportWorld.current
    ..backup = other
    ..content = other.content;
  await ImportScreenWorld.open(tester, Role.director);
}
