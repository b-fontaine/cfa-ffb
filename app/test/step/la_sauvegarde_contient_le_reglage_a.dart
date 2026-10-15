import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la sauvegarde contient le réglage {'passages requis'} à {3}
Future<void> laSauvegardeContientLeReglageA(
  WidgetTester tester,
  String name,
  num value,
) async {
  expect(TrackingWorld.current.backupSetting(name), value);
}
