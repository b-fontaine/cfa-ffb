import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';
import '../support/import_world.dart';

/// Usage: a synchronised club
Future<void> aSynchronisedClub(WidgetTester tester) async {
  ImportWorld.open().act(Role.director);
  ImportScreenWorld.reset();
}
