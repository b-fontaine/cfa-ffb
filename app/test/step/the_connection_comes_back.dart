import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_screen_world.dart';
import '../support/import_world.dart';

/// Usage: the connection comes back
Future<void> theConnectionComesBack(WidgetTester tester) async {
  ImportWorld.current.store.failAfterBatches = null;
  ImportScreenWorld.network
    ..setOnline(value: false)
    ..setOnline(value: true);
  await tester.pumpAndSettle();
}
