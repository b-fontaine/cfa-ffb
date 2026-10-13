import 'package:flutter_test/flutter_test.dart';

/// Usage: reduced animations are enabled on the device
Future<void> reducedAnimationsAreEnabledOnTheDevice(WidgetTester tester) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures.allOn;
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}
