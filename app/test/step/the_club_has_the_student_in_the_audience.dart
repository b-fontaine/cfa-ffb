import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the club has the student {'Léa'} in the {'children'} audience
Future<void> theClubHasTheStudentInTheAudience(
  WidgetTester tester,
  String name,
  String audience,
) => UiWorld.enroll(tester, name, UiWorld.audience(audience));
