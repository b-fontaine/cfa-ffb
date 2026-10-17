import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the club {'Club Nice'} exists
Future<void> theClubExists(WidgetTester tester, String club) async {
  await UiWorld.prepare(tester);
  UiWorld.memberships.club(UiWorld.clubIdOf(club), club);
}
