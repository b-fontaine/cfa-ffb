import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

/// Usage: the next day comes
Future<void> theNextDayComes(WidgetTester tester) async {
  ImportWorld.current.clock.advance(const Duration(days: 1));
}
