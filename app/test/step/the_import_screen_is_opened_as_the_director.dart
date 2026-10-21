import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';

/// Usage: the import screen is opened as the director
Future<void> theImportScreenIsOpenedAsTheDirector(WidgetTester tester) async {
  await ImportScreenWorld.open(tester, Role.director);
}
