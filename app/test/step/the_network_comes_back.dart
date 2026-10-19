import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the network comes back
Future<void> theNetworkComesBack(WidgetTester tester) async {
  UiWorld.network.setOnline(value: true);
  await tester.pumpAndSettle();
}
