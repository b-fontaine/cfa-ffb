import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the save dialog is cancelled
Future<void> theSaveDialogIsCancelled(WidgetTester tester) async {
  UiWorld.pdfSaveCancelled = true;
}
