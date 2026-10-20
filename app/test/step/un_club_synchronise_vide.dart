import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> unClubSynchroniseVide(WidgetTester tester) async {
  ImportWorld.open().act(Role.director);
}
