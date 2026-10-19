import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the network is lost
Future<void> theNetworkIsLost(WidgetTester tester) async {
  await UiWorld.prepare(tester);
  UiWorld.network.setOnline(value: false);
  await tester.pumpAndSettle();
}
