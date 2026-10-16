import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the club has the group {'Wednesday'} in the {'children'} audience
Future<void> theClubHasTheGroupInTheAudience(
  WidgetTester tester,
  String name,
  String audience,
) async {
  await UiWorld.createGroup(tester, name, UiWorld.audience(audience));
}
