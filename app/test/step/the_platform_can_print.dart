import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the platform can print
Future<void> thePlatformCanPrint(WidgetTester tester) async {
  UiWorld.pdfCanPrint = true;
}
