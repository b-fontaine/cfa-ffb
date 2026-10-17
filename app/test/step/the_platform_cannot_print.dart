import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the platform cannot print
Future<void> thePlatformCannotPrint(WidgetTester tester) async {
  UiWorld.pdfCanPrint = false;
}
