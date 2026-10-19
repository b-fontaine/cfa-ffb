import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the local data cache is then reopened
///
/// Web : la page se recharge après l'effacement (le SDK ne rouvre pas une
/// instance terminée).
Future<void> theLocalDataCacheIsThenReopened(WidgetTester tester) async {
  expect(UiWorld.localCache.reopens, 1);
}
