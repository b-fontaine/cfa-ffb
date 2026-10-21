import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';

/// Usage: another account opens the import screen
Future<void> anotherAccountOpensTheImportScreen(WidgetTester tester) async {
  await ImportScreenWorld.open(tester, Role.director, user: 'u-other');
}
