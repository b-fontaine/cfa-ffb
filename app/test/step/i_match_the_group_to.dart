import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';

/// Usage: I match the group {'Groupe 1'} to {'Match to: Mardi'}
Future<void> iMatchTheGroupTo(
  WidgetTester tester,
  String group,
  String option,
) async {
  await ImportScreenWorld.choose(
    tester,
    ImportScreenWorld.groupMenu(group),
    option,
  );
}
