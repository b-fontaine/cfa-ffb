import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the local data cache can be cleared again
Future<void> theLocalDataCacheCanBeClearedAgain(WidgetTester tester) async {
  UiWorld.localCache.clearFailure = null;
}
