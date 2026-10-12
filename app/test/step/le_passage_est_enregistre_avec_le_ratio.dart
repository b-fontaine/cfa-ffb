import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> lePassageEstEnregistreAvecLeRatio(
  WidgetTester tester,
  String ratio,
) async {
  final recorded = TrackingWorld.valueOf(TrackingWorld.current.lastRecord);
  final attempt = recorded.attempt;
  expect('${attempt.potted}/${attempt.total}', ratio);
}
