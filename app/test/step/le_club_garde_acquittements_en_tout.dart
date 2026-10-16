import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le club garde {1} acquittements en tout
Future<void> leClubGardeAcquittementsEnTout(
  WidgetTester tester,
  num count,
) async {
  expect(await TrackingWorld.current.acknowledgementCount(), count.toInt());
}
