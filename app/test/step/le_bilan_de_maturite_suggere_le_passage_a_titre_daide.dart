import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> leBilanDeMaturiteSuggereLePassageATitreDaide(
  WidgetTester tester,
) async {
  expect(TrackingWorld.current.assessment.readinessHint, isTrue);
}
