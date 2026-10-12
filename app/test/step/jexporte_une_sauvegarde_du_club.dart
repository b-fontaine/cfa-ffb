import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> jexporteUneSauvegardeDuClub(WidgetTester tester) async {
  await TrackingWorld.current.exportBackup();
}
