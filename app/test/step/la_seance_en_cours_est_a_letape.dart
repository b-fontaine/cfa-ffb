import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance en cours est {'posture-1'} à l'étape {2}
Future<void> laSeanceEnCoursEstALetape(
  WidgetTester tester,
  String sheet,
  num step,
) async {
  final running = TrackingWorld.current.running;
  expect(running, hasLength(1));
  expect(running.single.key.sheetId, SheetId(sheet));
  expect(running.single.step, step.toInt());
}
