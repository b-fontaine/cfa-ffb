import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: I note the number of open subscriptions
Future<void> iNoteTheNumberOfOpenSubscriptions(WidgetTester tester) async {
  await UiWorld.settle(tester);
  UiWorld.notedSubscriptions = UiWorld.documents.activeWatchers;
}
