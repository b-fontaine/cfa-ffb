import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the local data cache was cleared {1} times
Future<void> theLocalDataCacheWasClearedTimes(
  WidgetTester tester,
  int count,
) async {
  expect(UiWorld.localCache.clears, count);
}
