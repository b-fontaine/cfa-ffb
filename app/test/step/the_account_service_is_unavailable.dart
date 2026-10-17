import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the account service is unavailable
Future<void> theAccountServiceIsUnavailable(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  UiWorld.startup.available = false;
}
