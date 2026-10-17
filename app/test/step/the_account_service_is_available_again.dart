import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the account service is available again
Future<void> theAccountServiceIsAvailableAgain(WidgetTester tester) async {
  UiWorld.startup.available = true;
}
